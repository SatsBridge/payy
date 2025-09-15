extern crate proc_macro;

use proc_macro::TokenStream;
use quote::quote;
use syn::{
    parse_macro_input, Attribute, Data, DeriveInput, Fields, Lit, Meta, NestedMeta, Variant,
};

/// Derive macro for implementing `From<Error>` for HTTPError and `TryFrom<HTTPError>` for Error
#[proc_macro_derive(
    HTTPErrorConversion,
    attributes(bad_request, not_found, already_exists, failed_precondition)
)]
pub fn derive_http_error(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);

    // Extract the enum name and variants
    let enum_name = &input.ident;
    let variants = match &input.data {
        Data::Enum(data_enum) => &data_enum.variants,
        _ => panic!("HTTPErrorConversion can only be derived for enums"),
    };

    // Generate the From<Error> implementation
    let match_arms_to_http = variants.iter().map(|variant| {
        let variant_name = &variant.ident;

        // Find the HTTP error attribute
        let http_error_attr = find_http_error_attr(variant);

        if let Some((error_code, error_code_str)) = http_error_attr {
            // Handle different field types
            match &variant.fields {
                Fields::Unit => {
                    // Unit variant (no fields)
                    quote! {
                        #enum_name::#variant_name => HTTPError::new(
                            #error_code,
                            #error_code_str,
                            Some(err.into()),
                            None::<()>,
                        ),
                    }
                }
                Fields::Unnamed(fields) => {
                    // For tuple variants with a single field, pass that field as data
                    if fields.unnamed.len() == 1 {
                        // Use a reference pattern to avoid moving err
                        quote! {
                            #enum_name::#variant_name(ref data) => {
                                // Clone only the data
                                let data_clone = data.clone();

                                HTTPError::new(
                                    #error_code,
                                    #error_code_str,
                                    Some(err.into()),
                                    Some(data_clone),
                                )
                            },
                        }
                    } else {
                        // For tuple variants with multiple fields, we can't extract the data directly
                        quote! {
                            #enum_name::#variant_name(..) => HTTPError::new(
                                #error_code,
                                #error_code_str,
                                Some(err.into()),
                                None::<()>,
                            ),
                        }
                    }
                }
                Fields::Named(_) => {
                    // For named fields, we can't directly extract a data structure
                    quote! {
                        #enum_name::#variant_name { .. } => HTTPError::new(
                            #error_code,
                            #error_code_str,
                            Some(err.into()),
                            None::<()>,
                        ),
                    }
                }
            }
        } else {
            // No HTTP error attribute, use a default
            quote! {
                #enum_name::#variant_name { .. } => HTTPError::new(
                    ErrorCode::Internal,
                    "internal",
                    Some(err.into()),
                    None::<()>,
                ),
            }
        }
    });

    // Generate the TryFrom<HTTPError> implementation
    let match_arms_from_http = variants.iter().filter_map(|variant| {
        let variant_name = &variant.ident;

        // Find the HTTP error attribute
        let http_error_attr = find_http_error_attr(variant);

        if let Some((_, error_code_str)) = http_error_attr {
            // Handle different field types
            match &variant.fields {
                Fields::Unit => {
                    // Unit variant (no fields)
                    Some(quote! {
                        #error_code_str => Ok(#enum_name::#variant_name),
                    })
                }
                Fields::Unnamed(fields) => {
                    // For tuple variants with a single field, try to deserialize the data
                    if fields.unnamed.len() == 1 {
                        Some(quote! {
                            #error_code_str => {
                                if let Some(data) = http_error.data {
                                    // Try to deserialize the data
                                    let data = serde_json::from_value(data)
                                        .map_err(|_| TryFromHTTPError::DeserializationError)?;
                                    Ok(#enum_name::#variant_name(data))
                                } else {
                                    Err(TryFromHTTPError::MissingData)
                                }
                            },
                        })
                    } else {
                        // For tuple variants with multiple fields, we can't reconstruct the error
                        None
                    }
                }
                Fields::Named(_) => {
                    // For named fields, we can't reconstruct the error
                    None
                }
            }
        } else {
            None
        }
    });

    // Add a derive(Clone) requirement comment to help users
    let output = quote! {
        // Note: All data types used in tuple variants must implement Clone
        impl From<#enum_name> for HTTPError {
            fn from(err: #enum_name) -> Self {
                match err {
                    #(#match_arms_to_http)*
                }
            }
        }

        // Implement TryFrom<HTTPError> for Error
        impl std::convert::TryFrom<HTTPError> for #enum_name {
            type Error = TryFromHTTPError;

            fn try_from(http_error: HTTPError) -> Result<Self, Self::Error> {
                match http_error.reason.as_str() {
                    #(#match_arms_from_http)*
                    reason => Err(TryFromHTTPError::UnknownReason(reason.to_string())),
                }
            }
        }

        // Implement TryFrom<ErrorOutput> for Error
        impl std::convert::TryFrom<ErrorOutput> for #enum_name {
            type Error = TryFromHTTPError;

            fn try_from(error_output: ErrorOutput) -> Result<Self, Self::Error> {
                // Create an HTTPError from the ErrorOutput
                let http_error = HTTPError {
                    code: error_output.error.code,
                    reason: error_output.error.reason,
                    source: None,
                    data: error_output.error.data,
                    severity: ::rpc::error::Severity::Error
                };

                // Use the existing TryFrom<HTTPError> implementation
                Self::try_from(http_error)
            }
        }
    };

    output.into()
}

// Helper function to find and parse HTTP error attributes
fn find_http_error_attr(variant: &Variant) -> Option<(proc_macro2::TokenStream, String)> {
    for attr in &variant.attrs {
        if attr.path.is_ident("bad_request") {
            let error_code = quote! { ErrorCode::BadRequest };
            let error_code_str = extract_attr_string(attr);
            return Some((error_code, error_code_str));
        } else if attr.path.is_ident("not_found") {
            let error_code = quote! { ErrorCode::NotFound };
            let error_code_str = extract_attr_string(attr);
            return Some((error_code, error_code_str));
        } else if attr.path.is_ident("already_exists") {
            let error_code = quote! { ErrorCode::AlreadyExists };
            let error_code_str = extract_attr_string(attr);
            return Some((error_code, error_code_str));
        } else if attr.path.is_ident("failed_precondition") || attr.path.is_ident("internal") {
            let error_code = quote! { ErrorCode::FailedPrecondition };
            let error_code_str = extract_attr_string(attr);
            return Some((error_code, error_code_str));
        }
    }
    None
}

// Helper function to extract string from attribute
fn extract_attr_string(attr: &Attribute) -> String {
    match attr.parse_meta() {
        Ok(Meta::List(meta_list)) => {
            if let Some(NestedMeta::Lit(Lit::Str(lit_str))) = meta_list.nested.first() {
                lit_str.value()
            } else {
                panic!("Expected string literal in attribute");
            }
        }
        _ => panic!("Expected attribute with string argument"),
    }
}

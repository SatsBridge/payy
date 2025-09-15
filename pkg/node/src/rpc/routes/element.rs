use crate::Error;

use super::{error, State};
use actix_web::web;
use block_store::Block;
use element::Element;
use node_interface::{
    ElementData, ElementsResponse, ElementsResponseSingle, ListElementsQuery, RpcError,
};
use rpc::error::HttpResult;
use std::str::FromStr;

#[tracing::instrument(err, skip_all)]
pub async fn get_element(
    state: web::Data<State>,
    path: web::Path<(Element,)>,
) -> HttpResult<web::Json<ElementsResponseSingle>> {
    let (element,) = path.into_inner();
    Ok(web::Json(get_element_response(&state, element)?))
}

#[tracing::instrument(err, skip_all)]
pub async fn list_elements(
    state: web::Data<State>,
    query: web::Query<ListElementsQuery>,
) -> HttpResult<web::Json<ElementsResponse>> {
    if query.elements.is_empty() {
        return Ok(web::Json(vec![]));
    }

    let elements = query
        .elements
        .split(',')
        .map(|c| {
            Element::from_str(c)
                .map_err(|e| error::Error::InvalidElement(c.to_string(), e))
                .map_err(rpc::error::HTTPError::from)
        })
        .collect::<HttpResult<Vec<Element>>>()?;

    Ok(web::Json(
        elements
            .iter()
            .map(|element| match get_element_response(&state, *element) {
                Ok(response) => Ok(Some(response)),
                Err(e) => match e {
                    Error::Rpc(RpcError::ElementNotFound { .. }) => Ok(None),
                    _ => Err(e),
                },
            })
            .filter_map(Result::transpose)
            .collect::<crate::Result<Vec<ElementsResponseSingle>>>()?,
    ))
}

fn get_element_response(
    state: &web::Data<State>,
    element: Element,
) -> crate::Result<ElementsResponseSingle> {
    let notes_tree = state.node.notes_tree().read();
    let tree = notes_tree.tree();
    let meta = tree
        .get(element)
        .ok_or(RpcError::ElementNotFound(ElementData { element }))?;

    let Some(block) = state.node.get_block(meta.inserted_in.into())? else {
        return Err(crate::Error::BlockNotFound {
            block: meta.inserted_in.into(),
        });
    };

    let block = block.into_block();
    let root_hash = block.content.state.root_hash;
    let txn = block
        .content
        .state
        .txns
        .iter()
        .find(|txn| txn.public_inputs.commitments().contains(&element));

    let Some(txn) = txn else {
        // This should never happen in practice
        return Err(crate::Error::ElementNotInTxn {
            element,
            block_height: block.block_height(),
        });
    };
    let txn_hash = txn.hash();

    Ok(ElementsResponseSingle {
        element,
        height: meta.inserted_in,
        root_hash,
        txn_hash,
    })
}

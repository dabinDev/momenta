from fastapi import APIRouter, Query

from app.schemas.base import Fail, Success
from app.schemas.model_catalog import ModelCatalogApplyIn, ModelCatalogRecommendIn, ModelCatalogSyncIn
from app.services.model_catalog import ModelCatalogError, model_catalog_service

router = APIRouter()


@router.get("/list", summary="List model catalog")
async def list_model_catalog(
    service_type: str = Query("video", description="Service type"),
    scope: str = Query("global", description="Config scope"),
    user_id: int | None = Query(None, description="User ID for private scope"),
):
    try:
        data = await model_catalog_service.list_models(scope=scope, user_id=user_id, service_type=service_type)
    except ModelCatalogError as exc:
        return Fail(code=400, msg=str(exc))
    return Success(data=data)


@router.post("/sync", summary="Sync model catalog")
async def sync_model_catalog(sync_in: ModelCatalogSyncIn):
    try:
        data = await model_catalog_service.sync_models(
            scope=sync_in.scope,
            user_id=sync_in.user_id,
            service_type=sync_in.service_type,
        )
    except ModelCatalogError as exc:
        return Fail(code=400, msg=str(exc))
    return Success(data=data, msg="Model catalog synced")


@router.post("/recommend", summary="Recommend model")
async def recommend_model(recommend_in: ModelCatalogRecommendIn):
    try:
        data = await model_catalog_service.recommend_models(
            scope=recommend_in.scope,
            user_id=recommend_in.user_id,
            service_type=recommend_in.service_type,
            prioritize=recommend_in.prioritize,
            need_image_input=recommend_in.need_image_input,
        )
    except ModelCatalogError as exc:
        return Fail(code=400, msg=str(exc))
    return Success(data=data)


@router.post("/apply", summary="Apply model")
async def apply_model(apply_in: ModelCatalogApplyIn):
    try:
        data = await model_catalog_service.apply_model(
            scope=apply_in.scope,
            user_id=apply_in.user_id,
            service_type=apply_in.service_type,
            model_id=apply_in.model_id,
        )
    except ModelCatalogError as exc:
        return Fail(code=400, msg=str(exc))
    return Success(data=data, msg="Model applied")

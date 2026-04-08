import asyncio
import sys
from pathlib import Path

CURRENT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = CURRENT_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from tortoise import Tortoise

from app.controllers.task import task_controller
from app.core.init_app import ensure_runtime_schema
from app.models.video_task import VideoTask
from app.settings.config import settings


async def main() -> None:
    await Tortoise.init(config=settings.TORTOISE_ORM)
    await Tortoise.generate_schemas(safe=True)
    await ensure_runtime_schema()

    try:
        tasks = await VideoTask.filter(status="completed").order_by("id")
        total = len(tasks)
        updated = 0

        for index, task in enumerate(tasks, start=1):
            before_remote = str(task.remote_video_url or "").strip()
            before_cos = str(task.cos_video_url or "").strip()
            before_video = str(task.video_url or "").strip()

            urls = await task_controller.ensure_task_video_urls(task)
            changed = any(
                (
                    before_remote != urls["remote_video_url"],
                    before_cos != urls["cos_video_url"],
                    before_video != urls["video_url"],
                )
            )
            if changed:
                updated += 1

            print(
                f"[{index}/{total}] task={task.id} "
                f"remote={'yes' if urls['remote_video_url'] else 'no'} "
                f"cos={'yes' if urls['cos_video_url'] else 'no'} "
                f"changed={'yes' if changed else 'no'}"
            )

        print(f"backfill finished: total={total}, updated={updated}")
    finally:
        await Tortoise.close_connections()


if __name__ == "__main__":
    asyncio.run(main())

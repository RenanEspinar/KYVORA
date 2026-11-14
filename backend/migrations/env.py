from alembic import context
from app.db import engine,meta,url
if context.is_offline_mode():
    context.configure(url=url,target_metadata=meta,literal_binds=True)
    with context.begin_transaction():context.run_migrations()
else:
    with engine.connect() as c:
        context.configure(connection=c,target_metadata=meta,compare_type=True)
        with context.begin_transaction():context.run_migrations()

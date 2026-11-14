"""Persist advanced methods and their consecutive stages.

Revision ID: 03c1ec4200ab
Revises: 5d33343f82a1
"""
from alembic import op
import sqlalchemy as sa

revision='03c1ec4200ab'
down_revision='5d33343f82a1'
branch_labels=None
depends_on=None

def upgrade():
    op.add_column('workout_sets', sa.Column('method', sa.String(length=16), nullable=False,
        server_default='straight'))
    op.add_column('workout_sets', sa.Column('block_id', sa.String(length=36), nullable=True))
    op.add_column('workout_sets', sa.Column('phase', sa.Integer(), nullable=False,
        server_default='0'))

def downgrade():
    op.drop_column('workout_sets','phase')
    op.drop_column('workout_sets','block_id')
    op.drop_column('workout_sets','method')

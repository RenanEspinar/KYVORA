"""Provider IDs map to accounts independently of email (prevents email takeover)."""
from alembic import op
import sqlalchemy as sa
revision='04f2449200aa'
down_revision='03c1ec4200ab'
branch_labels=None
depends_on=None

def upgrade():
    op.create_table('auth_identities',
        sa.Column('provider',sa.String(length=16),nullable=False),
        sa.Column('subject',sa.String(length=255),nullable=False),
        sa.Column('user_id',sa.String(length=36),sa.ForeignKey('users.id',ondelete='CASCADE'),nullable=False),
        sa.Column('created_at',sa.DateTime(timezone=True),nullable=False),
        sa.PrimaryKeyConstraint('provider','subject'))
    op.create_index('ix_auth_identities_user_id','auth_identities',['user_id'])
    op.create_table('email_challenges',
        sa.Column('email',sa.String(length=254),primary_key=True),
        sa.Column('code_hash',sa.String(length=64),nullable=False),
        sa.Column('expires_at',sa.BigInteger(),nullable=False),
        sa.Column('attempts',sa.Integer(),nullable=False))

def downgrade():
    op.drop_table('email_challenges')
    op.drop_index('ix_auth_identities_user_id',table_name='auth_identities')
    op.drop_table('auth_identities')

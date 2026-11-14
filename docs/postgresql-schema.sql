BEGIN;

CREATE TABLE alembic_version (
    version_num VARCHAR(32) NOT NULL, 
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

-- Running upgrade  -> 5d33343f82a1

CREATE TABLE rate_limits (
    key VARCHAR(64) NOT NULL, 
    "window" BIGINT NOT NULL, 
    count INTEGER NOT NULL, 
    PRIMARY KEY (key)
);

CREATE TABLE users (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    username VARCHAR(24) NOT NULL, 
    password_hash VARCHAR(255) NOT NULL, 
    recovery_hash VARCHAR(64) NOT NULL, 
    PRIMARY KEY (id), 
    UNIQUE (username)
);

CREATE TABLE audit_events (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    actor_id VARCHAR(36), 
    action VARCHAR(50) NOT NULL, 
    resource_id VARCHAR(36) NOT NULL, 
    detail JSON NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(actor_id) REFERENCES users (id) ON DELETE SET NULL
);

CREATE TABLE auth_sessions (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    user_id VARCHAR(36) NOT NULL, 
    access_hash VARCHAR(64) NOT NULL, 
    access_until BIGINT NOT NULL, 
    expires BIGINT NOT NULL, 
    revoked BOOLEAN NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
    UNIQUE (access_hash)
);

CREATE INDEX ix_auth_sessions_user_id ON auth_sessions (user_id);

CREATE TABLE blocks (
    blocker VARCHAR(36) NOT NULL, 
    target VARCHAR(36) NOT NULL, 
    PRIMARY KEY (blocker, target), 
    FOREIGN KEY(blocker) REFERENCES users (id) ON DELETE CASCADE, 
    FOREIGN KEY(target) REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE body_measurements (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    owner_id VARCHAR(36) NOT NULL, 
    weight_kg FLOAT NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(owner_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_body_measurements_owner_id ON body_measurements (owner_id);

CREATE TABLE exercises (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    owner_id VARCHAR(36), 
    definition JSON NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(owner_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_exercises_owner_id ON exercises (owner_id);

CREATE TABLE follows (
    follower VARCHAR(36) NOT NULL, 
    followed VARCHAR(36) NOT NULL, 
    approved BOOLEAN NOT NULL, 
    PRIMARY KEY (follower, followed), 
    CHECK (follower <> followed), 
    FOREIGN KEY(followed) REFERENCES users (id) ON DELETE CASCADE, 
    FOREIGN KEY(follower) REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE media (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    owner_id VARCHAR(36) NOT NULL, 
    bytes INTEGER NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(owner_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_media_owner_id ON media (owner_id);

CREATE TABLE notifications (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    owner_id VARCHAR(36) NOT NULL, 
    actor_id VARCHAR(36) NOT NULL, 
    kind VARCHAR(30) NOT NULL, 
    resource_id VARCHAR(36) NOT NULL, 
    seen BOOLEAN NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(actor_id) REFERENCES users (id) ON DELETE CASCADE, 
    FOREIGN KEY(owner_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_notifications_owner_id ON notifications (owner_id);

CREATE TABLE profiles (
    user_id VARCHAR(36) NOT NULL, 
    display_name VARCHAR(60) NOT NULL, 
    bio VARCHAR(300) NOT NULL, 
    private BOOLEAN NOT NULL, 
    rankings_opt_in BOOLEAN NOT NULL, 
    personal JSON NOT NULL, 
    PRIMARY KEY (user_id), 
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE reports (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    owner_id VARCHAR(36) NOT NULL, 
    resource_type VARCHAR(20) NOT NULL, 
    resource_id VARCHAR(36) NOT NULL, 
    reason VARCHAR(1000) NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(owner_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE sync_operations (
    owner_id VARCHAR(36) NOT NULL, 
    operation_id VARCHAR(36) NOT NULL, 
    digest VARCHAR(64) NOT NULL, 
    response JSON NOT NULL, 
    PRIMARY KEY (owner_id, operation_id), 
    FOREIGN KEY(owner_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE workout_sessions (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    owner_id VARCHAR(36) NOT NULL, 
    name VARCHAR(100) NOT NULL, 
    started_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    ended_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    bodyweight_kg FLOAT, 
    notes VARCHAR(2000) NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(owner_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_workout_sessions_owner_id ON workout_sessions (owner_id);

CREATE TABLE workout_templates (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    owner_id VARCHAR(36) NOT NULL, 
    definition JSON NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(owner_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_workout_templates_owner_id ON workout_templates (owner_id);

CREATE TABLE refresh_tokens (
    digest VARCHAR(64) NOT NULL, 
    session_id VARCHAR(36) NOT NULL, 
    used BOOLEAN NOT NULL, 
    PRIMARY KEY (digest), 
    FOREIGN KEY(session_id) REFERENCES auth_sessions (id) ON DELETE CASCADE
);

CREATE INDEX ix_refresh_tokens_session_id ON refresh_tokens (session_id);

CREATE TABLE workout_exercises (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    workout_id VARCHAR(36) NOT NULL, 
    exercise_id VARCHAR(36) NOT NULL, 
    position INTEGER NOT NULL, 
    superset VARCHAR(24), 
    PRIMARY KEY (id), 
    FOREIGN KEY(exercise_id) REFERENCES exercises (id), 
    FOREIGN KEY(workout_id) REFERENCES workout_sessions (id) ON DELETE CASCADE, 
    UNIQUE (workout_id, position)
);

CREATE INDEX ix_workout_exercises_workout_id ON workout_exercises (workout_id);

CREATE TABLE workout_sets (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    move_id VARCHAR(36) NOT NULL, 
    position INTEGER NOT NULL, 
    kind VARCHAR(16) NOT NULL, 
    load_kg FLOAT NOT NULL, 
    reps INTEGER, 
    seconds FLOAT, 
    distance_m FLOAT, 
    rpe FLOAT, 
    rir INTEGER, 
    rest_seconds INTEGER NOT NULL, 
    PRIMARY KEY (id), 
    CHECK (load_kg >= 0), 
    FOREIGN KEY(move_id) REFERENCES workout_exercises (id) ON DELETE CASCADE, 
    UNIQUE (move_id, position)
);

CREATE INDEX ix_workout_sets_move_id ON workout_sets (move_id);

CREATE TABLE personal_records (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    owner_id VARCHAR(36) NOT NULL, 
    exercise_id VARCHAR(36) NOT NULL, 
    set_id VARCHAR(36) NOT NULL, 
    kind VARCHAR(24) NOT NULL, 
    value FLOAT NOT NULL, 
    load_kg FLOAT NOT NULL, 
    reps INTEGER NOT NULL, 
    bodyweight_kg FLOAT, 
    achieved_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    status VARCHAR(20) NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(exercise_id) REFERENCES exercises (id) ON DELETE CASCADE, 
    FOREIGN KEY(owner_id) REFERENCES users (id) ON DELETE CASCADE, 
    FOREIGN KEY(set_id) REFERENCES workout_sets (id) ON DELETE CASCADE, 
    UNIQUE (set_id, kind)
);

CREATE INDEX ix_personal_records_exercise_id ON personal_records (exercise_id);

CREATE INDEX ix_personal_records_owner_id ON personal_records (owner_id);

CREATE INDEX ix_personal_records_set_id ON personal_records (set_id);

CREATE TABLE posts (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    owner_id VARCHAR(36) NOT NULL, 
    text VARCHAR(2000) NOT NULL, 
    visibility VARCHAR(12) NOT NULL, 
    workout_id VARCHAR(36), 
    record_id VARCHAR(36), 
    media_id VARCHAR(36), 
    PRIMARY KEY (id), 
    FOREIGN KEY(media_id) REFERENCES media (id) ON DELETE SET NULL, 
    FOREIGN KEY(owner_id) REFERENCES users (id) ON DELETE CASCADE, 
    FOREIGN KEY(record_id) REFERENCES personal_records (id) ON DELETE SET NULL, 
    FOREIGN KEY(workout_id) REFERENCES workout_sessions (id) ON DELETE SET NULL
);

CREATE INDEX ix_posts_owner_id ON posts (owner_id);

CREATE INDEX ix_posts_time ON posts (created_at, id);

CREATE TABLE verification_requests (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    record_id VARCHAR(36) NOT NULL, 
    owner_id VARCHAR(36) NOT NULL, 
    witness_id VARCHAR(36) NOT NULL, 
    state VARCHAR(16) NOT NULL, 
    reason VARCHAR(500) NOT NULL, 
    flag BOOLEAN NOT NULL, 
    PRIMARY KEY (id), 
    CHECK (owner_id <> witness_id), 
    FOREIGN KEY(owner_id) REFERENCES users (id) ON DELETE CASCADE, 
    FOREIGN KEY(record_id) REFERENCES personal_records (id) ON DELETE CASCADE, 
    FOREIGN KEY(witness_id) REFERENCES users (id) ON DELETE CASCADE, 
    UNIQUE (record_id, witness_id)
);

CREATE INDEX ix_verification_requests_owner_id ON verification_requests (owner_id);

CREATE INDEX ix_verification_requests_record_id ON verification_requests (record_id);

CREATE INDEX ix_verification_requests_witness_id ON verification_requests (witness_id);

CREATE TABLE comments (
    id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    version INTEGER NOT NULL, 
    post_id VARCHAR(36) NOT NULL, 
    owner_id VARCHAR(36) NOT NULL, 
    text VARCHAR(1000) NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(owner_id) REFERENCES users (id) ON DELETE CASCADE, 
    FOREIGN KEY(post_id) REFERENCES posts (id) ON DELETE CASCADE
);

CREATE INDEX ix_comments_post_id ON comments (post_id);

CREATE TABLE reactions (
    post_id VARCHAR(36) NOT NULL, 
    owner_id VARCHAR(36) NOT NULL, 
    PRIMARY KEY (post_id, owner_id), 
    FOREIGN KEY(owner_id) REFERENCES users (id) ON DELETE CASCADE, 
    FOREIGN KEY(post_id) REFERENCES posts (id) ON DELETE CASCADE
);

INSERT INTO alembic_version (version_num) VALUES ('5d33343f82a1') RETURNING alembic_version.version_num;

COMMIT;


SELECT 'CREATE DATABASE langfuse' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'langfuse')\gexec
GRANT ALL PRIVILEGES ON DATABASE langfuse TO llmproxy;

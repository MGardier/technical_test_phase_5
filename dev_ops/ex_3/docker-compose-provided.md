
version: '3.8'
services:
  mattermost:
    image: mattermost/mattermost-team-edition:latest
    ports:
      - "8065:8065"
    environment:
      - MM_SQLSETTINGS_DRIVERNAME=postgres
      - MM_SQLSETTINGS_DATASOURCE=postgres://mattermost:password@postgres:5432/mattermost
      - MM_SERVICESETTINGS_SITEURL=http://localhost:8065
    volumes:
      - mattermost_data:/mattermost/data
      - mattermost_logs:/mattermost/logs
      - mattermost_plugins:/mattermost/plugins
    depends_on:
      - postgres

  postgres:
    image: postgres:13
    environment:
      - POSTGRES_USER=mattermost
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=mattermost
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  mattermost_data:
  mattermost_logs:
  mattermost_plugins:
  postgres_data:
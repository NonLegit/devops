### What is functional?

1. All three (backend/frontend/cross-platform) are deployed with docker on the main AWS EC2 instance. <br>Dockerfiles and docker-compose files are within *dockerfiles*.<br>For a reverse proxy, apache has been used. Somwhat incomplete apache virtual hosts files (with placeholder values to replace in the bootstrap script) are found within *configuration-management/apache*.
<br><br>
2. A standalone email server is configured on a DigitalOcean droplet using postfix and dovecot.
<br><br>
3. A CI/CD pipeline using jenkins is established. The bash scripts run within jenkins are in the *jenkins/bash-scripts* directory. Note that the base pipeline script invoking those is provided in the respective repositories of each team. 
<br><br>
4. A CloudFormation yaml file for the creation of all this infrastructure (spanning the two servers in the two cloud providers, and including: compute, networking, DNS, EFS) is provided in the iac directory. Any code that has been utilized within it (as Lambda functions), is included in the *misc* directory.
<br><br>
5. A boostrapping bash script is provided for the production instance, though not the separate email instance in the *configuration-management* directory.
<br><br>
6. ELK stack base configuration files are provided in the *elk* directory (ElasticSearch and Kibana). [Source mentioned in the README.mdinside the directory]. Alerts have been set (though manually through Kibana's dashboards, not in the scripts) for CPU and memory usage.

### Notes
1. I do not deploy a monolith docker-compose file each push/webhook trigger (though, there's a docker-compose file for it in the *dockerfiles* directory). Each service is deployed on its own.
2. E2E tests are not integrated in the pipeline.

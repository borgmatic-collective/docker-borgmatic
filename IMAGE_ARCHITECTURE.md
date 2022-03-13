```
docker-borgmatic/
├── base
│   ├── data
│   │   └── borgmatic.d
│   │       ├── config.yml
│   │       └── crontab.txt
│   ├── docker-compose.restore.yml     
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── entry.sh      
├── msmtp
│   ├── data
│   │   └── borgmatic.d
│   │       ├── config.yml             # same as in base
│   │       ├── crontab.txt            # with mailto
│   │       ├── mailenv.sh
│   │       └── msmtprc.sh
│   ├── docker-compose.yml             # image: b3vis/borgmatic:latest-msmtp, env: msmtp.env
│   ├── Dockerfile                     # FROM b3vis/borgmatic:${VERSION}
│   ├── entry.sh                       # starts msmtp in addition
│   └── README.md                      # describes specifics only
├── ntfy
│   ├── data
│   │   └── borgmatic.d
│   │       ├── config.yml             # same as in base
│   │       └── crontab.txt            # same as in base
│   ├── docker-compose.yml             # image: b3vis/borgmatic:latest-ntfy
│   ├── Dockerfile                     # FROM b3vis/borgmatic:${VERSION}
│   ├── entry.sh                       # same as in base
│   └── README.md                      # describes specifics only
└── README.md     
```

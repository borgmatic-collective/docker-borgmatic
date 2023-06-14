Here's a simple example of running this in a docker-compose environment.

Read through `docker-compose.yml` and change things as appropriate. Then do the same with `borgmatic.d/config.yml` and `borgmatic.d/crontab.txt`.

Start the container - `docker-compose up -d`.

At the moment, you need to initialize the repo manually. Connect to the container directly (`docker exec -it borgmatic bash`). If you want a repo without encryption, run `borgmatic init -e none`.

If you are using encryption, you'll need to do something else; I haven't written this section because I'm not using encryption (sorry! Please file a pull request if you figure it out!) Also, IT IS VITALLY IMPORTANT THAT YOU BACK UP `/config.borg/*` AND YOUR PASSPHRASE TO SOMEPLACE SAFE. YOU WILL NEED THESE TO RESTORE YOUR BACKUP. THIS IS NOT OPTIONAL.
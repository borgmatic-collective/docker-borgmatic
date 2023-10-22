#!/bin/sh

# Path
CRONTAB_PATH="/etc/borgmatic.d/crontab.txt"

#Variables
borgver=$(borg --version)
borgmaticver=$(borgmatic --version)
apprisever=$(apprise --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')

#Software versions
echo borgmatic $borgmaticver
echo $borgver
echo apprise $apprisever

# Uncomment the following lines for debugging to display the initial values of BORG_PASSPHRASE and BORG_PASSPHRASE_FILE.
# echo "Before: BORG_PASSPHRASE: ${BORG_PASSPHRASE}"
# echo "Before: BORG_PASSPHRASE_FILE: ${BORG_PASSPHRASE_FILE}"

# Iterate through all environment variables with the prefix 'BORG'.
for var_name in $(set | grep '^BORG' | awk -F= '{print $1}'); do
  # Retrieve the current value of the environment variable in question.
  var_value=$(eval echo \$$var_name)

  # Check if the variable name ends with the suffix '_FILE'.
  if [[ "$var_name" =~ _FILE$ ]]; then
    # Remove the '_FILE' suffix to derive the name of the corresponding "non-FILE" variable.
    original_var_name=${var_name%_FILE}

    # Check if the original (non-FILE) environment variable is already set and capture its value.
    original_var_value=$(eval echo \$$original_var_name)

    # Verify that the *_FILE variable is set, that the file it points to exists, and that the file is not empty.
    if [ -n "$var_value" ] && [ -s "$var_value" ]; then
      # Notify the user if the original (non-FILE) variable is being overwritten.
      if [ -n "$original_var_value" ]; then
        echo "Note: $original_var_name was already set but is being overwritten by $var_name"
      fi

      # Read the file content and store it in the original (non-FILE) environment variable.
      export "$original_var_name"=$(cat "$var_value")
      echo "Setting $original_var_name from the content of $var_value"

      # Remove the original *_FILE environment variable
      unset "$var_name"
      echo "Unsetting $var_name"
    else
      # Issue an error message if the file does not exist or is empty.
      echo "Error: File $var_value does not exist or is empty."
    fi
  fi
done

# Uncomment the following lines for debugging to display the final values of BORG_PASSPHRASE and BORG_PASSPHRASE_FILE.
# echo "After: BORG_PASSPHRASE: ${BORG_PASSPHRASE}"
# echo "After: BORG_PASSPHRASE_FILE: ${BORG_PASSPHRASE_FILE}"
# exit 1


if [ $# -eq 0 ]; then

  # Allow setting of custom crontab, so check if crontab file exists
  if [ -f "$CRONTAB_PATH" ]; then
    echo "Crontab file exists, using it"
  else
    if [ -z "${BACKUP_CRON}" ]; then
      echo "Environment variable BACKUP_CRON is not set, using default value: 0 1 * * *"
      export BACKUP_CRON="0 1 * * *"
    else
      echo "Environment variable BACKUP_CRON is set, using value $BACKUP_CRON"
    fi
    echo "$BACKUP_CRON PATH=\$PATH:/usr/local/bin /usr/local/bin/borgmatic --stats -v 0 2>&1" > $CRONTAB_PATH
  fi

  if [ "${RUN_ON_STARTUP:-}" == "true" ]; then
    echo "Running on startup..."
    /usr/local/bin/borgmatic --stats -v 0 2>&1
  fi

  # Test crontab
  supercronic -test /etc/borgmatic.d/crontab.txt || exit 1

  # Start supercronic
  if [ -n "${SUPERCRONIC_EXTRA_FLAGS}" ]; then
    echo "The variable SUPERCRONIC_EXTRA_FLAGS is not empty, using extra flags"
    exec supercronic $SUPERCRONIC_EXTRA_FLAGS /etc/borgmatic.d/crontab.txt
  else
    echo "The variable SUPERCRONIC_EXTRA_FLAGS is empty, starting normally"
    exec supercronic /etc/borgmatic.d/crontab.txt
  fi
else
  if [ "$1" = "bash" ] || [ "$1" = "sh" ] || [ "$1" = "/bin/bash" ] || [ "$1" = "/bin/sh" ]; then
    # Run Shell
    exec "$@"
  else
    # Run borgmatic with subcommand
    exec borgmatic "$@"
  fi
fi

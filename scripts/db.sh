##############################################################################
# Database management script
#
# This script contains functions for database management, and will invoke the
# appropriate function based on the arguments passed to it.
##############################################################################

list_databases() {
	ssh -t $user@$ip "mysql -p -e 'show databases'"
}

list_users() {
	ssh -t $user@$ip "mysql -p -e 'select user from mysql.user'"
}

create_db() {
	while [[ $# -gt 0 ]] ; do
	    arg=$1 ; shift
	    case $arg in
			-n|--name) dbname=$arg ; shift;;
			--name=*) dbname=${arg#*=};;
			-u|--user) dbuser=$arg ; shift;;
			--user=*) dbuser=${arg#*=};;
	        *) echo "Unknown argument: $arg" ; exit 1;;
	    esac
	done
	if [[ -z $dbname ]] || [[ -z $dbuser ]] ; then
		cat <<-.
		Create a database and user that has permissions only on that database
		You will be prompted to choose a password for the new database user,
		this should be an alphanumeric password.

		-n,--name <dbname> -- name of the database to create
		-u,--user <dbuser> -- name of the user to create

		Example:
		    $(basename $0) db create -n example_db -u example_user
		    $(basename $0) db create --name=blog_db --user=blog_user
		.
		die
	fi

	read -sp 'Password:' dbpass
	read -sp 'Confirm Password' confirm_pass

	if [[ "$dbpass" != "$confirm_pass" ]]; then
		echo 'ERROR: passwords do not match!'
		exit 1
	fi

	cat <<-message
	creating database:
	    database: $dbname
	    user:     $dbuser

	When prompted, enter your *database administrator* password to continue
	message

	ssh -t $user@$ip "mysql -p <<sql
	CREATE DATABASE IF NOT EXISTS $dbname;
	CREATE USER IF NOT EXISTS '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';
	GRANT ALL ON ${dbname}.* TO '$dbuser'@'localhost';
	FLUSH PRIVILEGES;
sql"

	[[ $? -eq 0 ]] && echo 'Database Created!'
}

backup_db() {
	while [[ $# -gt 0 ]] ; do
	    arg=$1 ; shift
	    case $arg in
	        -n|--name) database=$arg ; shift;;
	        --name=*) database=${arg#*=};;
			-o|--outfile) outputfile=$arg ; shift;;
			--outfile=*) outputfile=${arg#*=};;
	        *) echo "Unknown argument: $arg" ; exit 1;;
	    esac
	done
	if [[ -z $database ]]; then
		cat <<-.
		Create a backup of a database. Optionally specify a filename to save the
		backup to. Will default to a file with the current time and the database
		name inside of $BASE_DIR/db-backups

		-n,--name    <database>   -- name of the database to backup
		-o,--outfile <outputfile> -- (optional) file to store the backup in

		Examples:
		    $(basename $0) db backup -d example_db
		    $(basename $0) db backup --name=blog_db --outfile=~/blog_db-dump.sql
		.
		die
	fi
	if [[ -z $outputfile ]]; then
		outputfile="$BASE_DIR/db-backups/$(date +%Y-%m-%d_%H:%M:%S)-${database}-backup.sql"
	fi

	read -sp 'Database Password: ' db_pass
	echo -e "\nbacking up...."
	ssh -t $user@$ip "mysqldump -p${db_pass} ${database} 2>/dev/null" > $outputfile
	echo
	echo "$outputfile created!"
}

remove_db() {
	while [[ $# -gt 0 ]] ; do
	    arg=$1 ; shift
	    case $arg in
	        -n|--name) db_name=$arg ; shift;;
	        --name=*) db_name=${arg#*=};;
			-u|--user) db_user=$arg ; shift;;
			--user=*) db_user=${arg#*=};;
	        *) echo "Unknown argument: $arg" ; exit 1;;
	    esac
	done
	while getopts 'd:u:' opt ; do
		case $opt in
			d) db_name=${OPTARG};;
			u) db_user=${OPTARG};;
		esac
	done
	if [[ -z $db_name ]] || [[ -z $db_user ]] ; then
		cat <<-.
		Remove a database and database user

		-d <database> -- name of the database to remove
		-u <username> -- name of the database user to remove

		Examples:
		    $(basename $0) db rm -n example_db -u example_user
		    $(basename $0) db remove --name=blog_db --user=blog_user
		.
		die
	fi

	ssh -t $user@$ip "mysql -p -e 'DROP DATABASE ${db_name}'
					  mysql -p -e 'DROP USER ${db_user}@localhost'"
	[[ $? -eq 0 ]] && echo 'Database Removed!'
}

login() {
	ssh -t $user@$ip mysql -p
}

show_usage() {
	cat <<-help_message
	db -- command for interacting with databases on your server
	usage

	    $(basename $0) db <command> [options]

	where <command> is one of the following:

	    login
	    list
	    create -n <dbname> -u <user>
	    remove -n <dbname> -u <user>
	    backup -n <dbname> [-f <outputfile>]

	help_message
}

command=$1
shift

case $command in
	create)    create_db $@;;
	backup)    backup_db $@;;
	remove|rm) remove_db $@;;
	list|ls)   list_databases;;
	login)     login;;
	*)         show_usage;;
esac

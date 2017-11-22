##############################################################################
# Site management script
#
# This script contains functions for site management, and will run the
# appropriate function based on the arguments passed to it. Most of the
# functionality here is for setting up nginx and tomcat to host sites, as well
# as enabling https for sites.
##############################################################################

list_sites() {
	ssh $user@$ip 'ls -1 /etc/nginx/sites-available' | grep -v '^default$'
}

ensure_site_exists() {
	site=$1
	if ! list_sites | grep "^${site}$" >/dev/null ; then
		echo "It looks like $site is not setup."
		echo 'Aborting...'
		exit 1
	fi
}

create_site() {
	domain=$1
	if [[ -z $domain ]]; then
		read -p 'Enter the site name without the www: ' domain
	fi

	if list_sites | grep "^$domain$" > /dev/null ; then
		echo 'It looks like that site is already setup. Doing nothing.'
		echo 'If you wish to re-create the site, first remove the site, then'
		echo 're-create it.'
		exit 1
	fi

	# verify dns records
	if [[ "$(dig +short ${domain} | tail -n 1)" != $ip ]]; then
		echo 'It looks like the dns records for that domain are not setup to'
		echo 'point to your server.'
		read -p 'Continue anyway? [y/N] ' confirm
		echo $confirm | grep -i '^y' >/dev/null || exit 1
	fi

	ssh -t $user@$ip "
	domain=$domain
	$(< $SNIPPETS/create-tomcat-site.sh)
	$(< $SNIPPETS/create-nginx-site.sh)
	$(< $SNIPPETS/enable-git-deployment.sh)
	"

	echo "$domain setup!"
	echo
	echo "Here is your deployment remote:"
	echo
	echo "	$user@$ip:/srv/${domain}/repo.git"
	echo
	echo "You can run something like:"
	echo
	echo "	git remote add production $user@$ip:/srv/${domain}/repo.git"
	echo
	echo "To add the remote."
}

enable_ssl() {
	domain=$1
	if [[ -z $domain ]]; then
		read -p 'Enter the domain: ' domain
	fi

	ensure_site_exists $domain

	echo 'Before running this command, make sure that the DNS records for your domain'
	echo 'are configured to point to your server.'
	echo 'If they are not properly configured, this command *will* fail.'
	echo
	read -p 'Press Enter to continue, or Ctrl-C to exit'

	ssh -t $user@$ip "
	domain=$domain
	email=$email
	$(< $SNIPPETS/enable-ssl.sh)
	"

	[[ $? -eq 0 ]] && echo "https enabled for ${domain}!"
}

remove_site() {
	site=$1
	if [[ -z "$site" ]]; then
		read -p 'Enter the name of the site to remove: ' site
	fi

	# confirm deletion
	read -p "Are your sure you want to remove $site? [y/N] " confirm
	echo ! "$confirm" | grep -i '^y' >/dev/null ; then
		echo 'site not removed!'
		exit 1
	fi

	ensure_site_exists $site

	ssh -t $user@$ip "
	domain=$site
	$(< $SNIPPETS/remove-site.sh)
	"

	[[ $? -eq 0 ]] && echo "${domain} removed!"
}

build_site() {
	site=$1
	if [[ -z "$site" ]]; then
		read -p 'Enter the name of the site you wish to trigger a build for: ' site
	fi

	ensure_site_exists $site

	echo "Running post-receive hook for $site"
	ssh -t $user@$ip "
	cd /srv/$site/repo.git
	hooks/post-receive
	"
}

deploy_site() {
	site=$1
	war_filepath="$2"
	if [[ -z "$site" ]]; then
		read -p 'Enter the name of the site you want to deploy to: ' site
	fi
	if [[ -z "$war_filepath"  ]]; then
		read -ep 'Enter the path to the war file: ' war_filepath
		# parse the home directory correctly
		if echo "$war_filepath" | grep '^~' ; then
			war_filepath=$(echo "$war_filepath" | perl -pe "s!~!$HOME!")
		fi
	fi

	# ensure file exists and is a war (or at least has the extension)
	if [[ ! -f $war_filepath ]]; then
		echo 'It looks like that file does not exist!'
		exit 1
	fi
	if ! echo "$war_filepath" | grep '\.war$' >/dev/null ; then
		echo 'must be a valid .war file'
		exit 1
	fi

	ensure_site_exists $site

	scp $war_filepath $user@$ip:/opt/tomcat/$site/ROOT.war
}

show_info() {
	site=$1
	if [[ -z $site ]]; then
		read -p 'Site name: ' site
	fi

	ensure_site_exists $site

	cat <<-.
		Site: $site

		uploads directory:     /var/www/$site/uploads
		nginx config file:     /etc/nginx/sites-available/$site
		deployment git remote: $user@$ip:/srv/$site/repo.git

		To add the deployment remote (from your project, not from $BASE_DIR):

		    git remote add production $user@$ip:/srv/$site/repo.git

	.
}

show_help() {
	cat <<-help
	site -- command for managing sites setup on your server
	usage

	    ./server site <command>

	where <command> is one of the following:

	    list
	    create    [sitename]
	    remove    [sitename]
	    build     [sitename]
	    enablessl [sitename]
	    info      [sitename]
	    deploy    [sitename [/path/to/site.war]]

	help
}

command=$1
shift

case $command in
	list|ls)   list_sites;;
	create)	   create_site $@;;
	remove|rm) remove_site $@;;
	build)	   build_site $@;;
	enablessl) enable_ssl $@;;
	info)      show_info $@;;
	deploy)	   deploy_site $@;;
	*)         show_help;;
esac

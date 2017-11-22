# variables
#	- $domain: the domain to setup

set -u
set -e

echo "Adding virtual hosts entry for $domain"
# find our comment that marks the virtual hosts config and append an element
# for this site
sudo perl -i -pe "s!^.*--## Virtual Hosts ##--.*\$!$&\n\
<Host name=\"${domain}\" appBase=\"${domain}\" unpackWARs=\"true\" autoDeploy=\"true\" />!" \
	/opt/tomcat/conf/server.xml

echo "Creating directories for $domain"
sudo mkdir -p /opt/tomcat/${domain}
sudo chown -R tomcat:tomcat /opt/tomcat/${domain}
sudo chmod -R g+w /opt/tomcat/${domain}

echo 'Restarting tomcat...'
sudo systemctl restart tomcat

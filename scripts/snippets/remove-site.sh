# variables
#	- $domain: the domain to remove

echo "Removing $domain from tomcat configuration..."
sudo sed -i -e '/${domain}/d' /opt/tomcat/conf/server.xml

echo "Removing directories for $domain..."
sudo rm -f /etc/nginx/sites-available/${domain}
sudo rm -f /etc/nginx/sites-enabled/${domain}
sudo rm -rf /opt/tomcat/${domain}
sudo rm -rf /opt/tomcat/conf/Catalina/${domain}
sudo rm -rf /var/www/${domain}
sudo rm -rf /srv/${domain}

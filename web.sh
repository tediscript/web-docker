#!/bin/bash

function version()
{
    echo ""
    echo "################################"
    echo "## Docker Based WebEngine 1.0 ##"
    echo "################################"
    echo ""
}

function echo_nginx()
{
    docker exec -it ${NGINX_CONTAINER_NAME} echo "${1}"
}

function sh_nginx()
{
    docker exec -it ${NGINX_CONTAINER_NAME} sh -c "${1}"
}

function sh_php()
{
    docker exec -it ${PHP_CONTAINER_NAME} sh -c "${1}"   
}

function sh_db()
{
    docker exec -it ${DB_CONTAINER_NAME} sh -c "${1}"
}

function update_script()
{
    # if [ $# -eq 0 ]; then
    #     echo "updating from master..."
    #     wget -qO /usr/local/bin/web https://raw.githubusercontent.com/tediscript/web/master/web.sh
    # elif [ ${1} == "--dev" ]; then
    #     echo "updating from dev..."
    #     wget -qO /usr/local/bin/web https://raw.githubusercontent.com/tediscript/web/dev/web.sh
    # else
    #     version
    # fi
    # chmod +x /usr/local/bin/web
    # echo "web script updated!"
    # web -v
    echo ""
    echo "command not supported"
}

function site_enable()
{
    echo ""
    echo "enable ${1}..."
    sh_nginx "ln -s /etc/nginx/sites-available/${1} /etc/nginx/sites-enabled/${1}"
    sh_nginx "service nginx reload"
    echo "${1} enabled!"
}

function site_disable()
{
    echo ""
    echo "disable ${1}..."
    sh_nginx "rm /etc/nginx/sites-enabled/${1}"
    sh_nginx "service nginx reload"
    echo "${1} disabled!"
}

function site_create_database()
{
    echo ""
    echo "create database for ${1}"

    export LC_CTYPE=C
    local name=${1//[^a-z0-9]/_}
    local pass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

    #create mysql user and database
    sh_nginx "mkdir -p /var/www/${1}/conf"
    sh_nginx "echo \"### MySQL Config ###
database=${name}
username=${name}
password=${pass}\" > /var/www/${1}/conf/mysql.conf"

    #create database
    sh_db "mysql --user=root --password=${DB_ROOT_PASSWORD} -e \"CREATE DATABASE IF NOT EXISTS ${name};
    CREATE USER '${name}'@'localhost' IDENTIFIED BY '${pass}';
    GRANT ALL PRIVILEGES ON ${name}.* TO '${name}'@'localhost';
    CREATE USER '${name}'@'%' IDENTIFIED BY '${pass}';
    GRANT ALL PRIVILEGES ON ${name}.* TO '${name}'@'%';
    FLUSH PRIVILEGES;\""

    echo "database created!"
}

function site_create_web_directory()
{
    echo ""
    echo "create web directory for ${1}..."
    sh_nginx "mkdir -p /var/www/${1}/src/public"
    sh_nginx "chown -Rf www-data:www-data /var/www/${1}/src"
    echo "directory created!"
}

function site_create_nginx_conf()
{
    echo ""
    echo "create nginx config for ${1}..."
    sh_nginx "echo \"### ${1} ###
server {
    listen 80;

    if (\\\$host = www.${1}) {
        return 301 \\\$scheme://${1}\\\$request_uri;
    }

    # Webroot Directory
    root /var/www/${1}/src/public;
    index index.php index.html index.htm;

    # Your Domain Name
    server_name ${1} www.${1};

    location / {
        try_files \\\$uri \\\$uri/ /index.php?\\\$query_string;
    }

    # PHP-FPM Configuration Nginx
    location ~ \.php$ {
        try_files \\\$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \\\$document_root\\\$fastcgi_script_name;
        fastcgi_param PATH_INFO \\\$fastcgi_path_info;
        
    }

    # Log files for Debugging
    access_log /var/log/nginx/${1}-access.log;
    error_log /var/log/nginx/${1}-error.log;
}
\" > /etc/nginx/sites-available/${1}"
    echo "nginx config created!"
}

function site_install_helloworld()
{
    echo ""
    echo "install helloworld in ${1}..."
    sh_nginx "echo \"<h1>It works!</h1>\" > /var/www/${1}/src/public/index.php"
    sh_nginx "echo \"<?php phpinfo();\" > /var/www/${1}/src/public/info.php"
    sh_nginx "chown -Rf www-data:www-data /var/www/${1}/src/public"
}

function site_install_laravel()
{
    echo ""
    echo "install laravel in ${1}..."
    sh_php "cd /var/www/${1} \
        && rm -Rf ${APP_LARAVEL_TAG_VERSION} \
        && composer create-project laravel/laravel:${APP_LARAVEL_TAG_VERSION} ${APP_LARAVEL_TAG_VERSION} --prefer-dist \
        && cd ${APP_LARAVEL_TAG_VERSION} \
        && . /var/www/${1}/conf/mysql.conf \
        && cp .env .env.bak \
        && sed \"s/APP_NAME=Laravel/APP_NAME=${1}/g\" .env.bak \
        | sed \"s/APP_URL=http:\/\/localhost/APP_URL=http:\/\/${1}/g\" \
        | sed \"s/DB_HOST=127.0.0.1/DB_HOST=db/g\" \
        | sed \"s/DB_DATABASE=laravel/DB_DATABASE=\${database}/g\" \
        | sed \"s/DB_USERNAME=root/DB_USERNAME=\${username}/g\" \
        | sed \"s/DB_PASSWORD=/DB_PASSWORD=\${password}/g\" > .env \
        && cd .. \
        && chown -Rf www-data:www-data ${APP_LARAVEL_TAG_VERSION} \
        && mv src \"src-\$(date +'%Y%m%d%H%M%S')-bak\" \
        && mv ${APP_LARAVEL_TAG_VERSION} src"
    echo "laravel installed!"
}

function site_install_wordpress()
{
    echo ""
    echo "install wordpress in ${1}..."
    sh_php "cd /var/www/${1} \
        && rm -Rf ${APP_WORDPRESS_TAG_VERSION} \
        && composer create-project johnpbloch/wordpress:${APP_WORDPRESS_TAG_VERSION} ${APP_WORDPRESS_TAG_VERSION} --prefer-dist \
        && cd ${APP_WORDPRESS_TAG_VERSION} \
        && mv wordpress public \
        && . /var/www/${1}/conf/mysql.conf \
        && cd public \
        && sed \"s/database_name_here/\$database/g\" wp-config-sample.php \
        | sed \"s/username_here/\$username/g\" \
        | sed \"s/password_here/\$password/g\" \
        | sed \"s/localhost/db/g\" > wp-config.php \
        && STR_PATTERN='put your unique phrase here' \
        && STR_REPLACE=\$(curl -L https://api.wordpress.org/secret-key/1.1/salt/) \
        && printf '%s\n' \"g/\$STR_PATTERN/d\" a \"\$STR_REPLACE\" . w \
        | ed -s wp-config.php \
        && cd ../.. \
        && chown -Rf www-data:www-data ${APP_WORDPRESS_TAG_VERSION} \
        && mv src \"src-\$(date +'%Y%m%d%H%M%S')-bak\" \
        && mv ${APP_WORDPRESS_TAG_VERSION} src"
    echo "wordpress installed!"
}

function site_install()
{
    if [ -z "$2" ] || [ ${2} == "--helloworld" ] || [ ${2} == "--base" ]; then
        site_install_helloworld ${1}
    elif [ ${2} == "--laravel" ]; then
        site_install_laravel ${1}
    elif [ ${2} == "--wp" ] || [ ${2} == "--wordpress" ]; then
        site_install_wordpress ${1}
    else
        echo "${2} command not supported"
    fi
}

function site_create()
{
    #check is domain exist (and sites-available)
    echo ""
    echo "create ${1}..."

    #create web root and default index.php file
    site_create_web_directory ${1}

    #create database
    site_create_database ${1}

    #create nginx configuration
    site_create_nginx_conf ${1}

    #enable site
    site_enable ${1}

    #install application
    site_install ${1} ${2}

    echo ""
    echo "${1} created!"
}

function site_delete_nginx_conf()
{
    echo ""
    echo "delete nginx conf ${1}..."
    sh_nginx "rm -f /etc/nginx/sites-available/${1}"
    echo "nginx conf deleted!"
}

function site_delete_web_directory()
{
    echo ""
    echo "delete web root directory..."
    sh_nginx "rm -Rf /var/www/${1}"
    echo "web root directory deleted!"
}

function site_delete_database()
{
    echo ""
    echo "delete database ${1}..."
    local name=${1//[^a-z0-9]/_}
    sh_db "mysql -u root -p${DB_ROOT_PASSWORD} -e \"DROP DATABASE IF EXISTS ${name};
    DROP USER '${name}'@'localhost';
    DROP USER '${name}'@'%';\""
    echo "database deleted!"
}

function site_delete_log()
{
    echo ""
    echo "delete log ${1}..."
    sh_nginx "rm -f /var/log/nginx/${1}-access.log"
    sh_nginx "rm -f /var/log/nginx/${1}-error.log"
    echo "log deleted!"
}

function site_delete()
{
    echo ""
    echo "delete ${1}..."
    
    #delete site enable
    site_disable ${1}
    
    #site available
    site_delete_nginx_conf ${1}

    #delete folder /var/www/${1}
    site_delete_web_directory ${1}

    #delete database
    site_delete_database ${1}

    #delete log data
    site_delete_log ${1}

    echo ""
    echo "${1} deleted!"
}

function site_list()
{
    echo ""
    echo "all sites:"
    sh_nginx "ls /etc/nginx/sites-available | egrep -v '*\.save'"
    echo ""
    echo "active sites:"
    sh_nginx "ls /etc/nginx/sites-enabled | cat"
}

function site()
{
    if [ ${1} == "create" ]; then
        site_create ${2} ${3}
    elif [ ${1} == "install" ]; then
        site_install ${2} ${3}
    elif [ ${1} == "delete" ]; then
        site_delete ${2}
    elif [ ${1} == "enable" ]; then
        site_enable ${2}
    elif [ ${1} == "disable" ]; then
        site_disable ${2}
    elif [ ${1} == "list" ]; then
        site_list
    else
        echo "command not supported"
    fi
}

function host()
{
    if [ ${1} == "add" ]; then
        echo "127.0.0.1 ${2}" >> /etc/hosts
    elif [ ${1} == "remove" ]; then
        sed "s/127.0.0.1 ${2}//" /etc/hosts > hosts.bak && mv hosts.bak /etc/hosts
    else
        echo "command not supported"
    fi
    sed -i '' '/^$/d' /etc/hosts
}

function load_env()
{
    export $(grep -v '^#' .env | xargs)
}

function main()
{
    if [ -z "$1" ] || [ ${1} == "-v" ] || [ ${1} == "version" ]; then
        version
    elif [ ${1} == "update" ]; then
        update_script ${2}
    elif [ ${1} == "site" ]; then
        site ${2} ${3} ${4}
    elif [ ${1} == "host" ]; then
        host ${2} ${3}
    else
        echo "command not supported"
    fi    
}

###========###MAIN###========###

load_env
main ${1} ${2} ${3} ${4}

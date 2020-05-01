#!/bin/bash
php_versions="5.6|7.0|7.1|7.2|7.3|7.4"
php_base_packs="fpm|mysql|redis|mbstring|tokenizer|xml"
web_default_user="www-data"
web_default_group="www-data"

edit_equal_config() {
     filepath=$1
     var_name=$2
     var_value=$3
     sed -i -e "s|$var_name = .*|$var_name = $var_value|" $filepath
}

edit_nginx_config() {
     filepath=$1
     var_name=$2
     var_value=$3
     sed -i -e "s|$var_name .*;|$var_name  $var_value;|" $filepath
}

common_all_server() {
     /etc/init.d/mysql $1
     /etc/init.d/nginx $1
     for php_version in $(echo $php_versions | sed 's/|/ /g'); do
          /etc/init.d/php$php_version-fpm $1
     done
}

init_env() {
     echo "Install Base Env"
     apt update && apt upgrade
     apt install sudo curl vim wget unzip apt-transport-https lsb-release ca-certificates gnupg2 wget -y
}

install_php() {
     wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
     sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
     apt update
     for php_version in $(echo $php_versions | sed 's/|/ /g'); do
          apt install "php$php_version" -y
          for php_base_pack in $(echo $php_base_packs | sed 's/|/ /g'); do
               apt install "php$php_version\-$php_base_pack" -y
          done
     done
}

install_nginx() {
     echo "deb http://nginx.org/packages/debian $(lsb_release -cs) nginx" |
          sudo tee /etc/apt/sources.list.d/nginx.list
     curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add -
     apt-key fingerprint ABF5BD827BD9BF62
     apt remove apache2 -y
     apt update && apt install nginx -y
}

install_mysql() {
     deb_name="mysql-apt-config_0.8.15-1_all.deb"
     wget "https://repo.mysql.com//$deb_name"
     dpkg -i "./$deb_name"
     apt-get update && apt-get install mysql-server -y

}

install_composer() {
     php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
     php -r "if (hash_file('sha384', 'composer-setup.php') === 'e0012edf3e80b6978849f5eff0d4b4e4c79ff1609dd1e613307e16318854d24ae64f26d17af3ef0bf7cfb710ca74755a') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
     php composer-setup.php
     php -r "unlink('composer-setup.php');"
     mkdir /usr/share/composer
     mv ./composer.phar /usr/share/composer
     for php_version in $(echo $php_versions | sed 's/|/ /g'); do
          echo "#!/bin/bash
php$php_version /usr/share/composer/composer.phar
" >/usr/bin/composer-php$php_version
          chmod 755 /usr/bin/composer-php$php_version
          echo "Install Composer Command: composer-php$php_version"
     done
}

echo_default_php_nginx_conf_tpl() {
     filepath=$1
     echo "server {
    listen       80;
    server_name  localhost;
    root   /usr/share/nginx/html;

    #charset koi8-r;
    #access_log  /var/log/nginx/host.access.log  main;

    location / {
        root   /usr/share/nginx/html;
        index  index.php index.html index.htm;
    }

    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    location ~ \.php$ {
       fastcgi_pass   127.0.0.1:9000;
       fastcgi_index  index.php;
       fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
       include        fastcgi_params;
    }

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}
}" >$1
}

#初始化配置Nginx与PHP
init_conf_nginx_php() {
     edit_nginx_config "/etc/nginx/nginx.conf" "user" $web_default_user
     echo '<center><h1>LNMP</h1><center> <?php phpinfo(); ?>' >/var/www/html/index.php
     for php_version in $(echo $php_versions | sed 's/|/ /g'); do
          #Config PHP-FPM Default
          fpm_filepath="/etc/php/$php_version/fpm/pool.d/www.conf"
          php_listen_sock="/run/php/php$php_version-fpm.sock"
          edit_equal_config $fpm_filepath "listen" $php_listen_sock
          edit_equal_config $fpm_filepath "user" $web_default_user
          edit_equal_config $fpm_filepath "group" $web_default_group
          #Config Nginx Default
          nginx_default_path="/etc/nginx/conf.d/default-php$php_version.conf"
          echo_default_php_nginx_conf_tpl $nginx_default_path
          edit_nginx_config $nginx_default_path "root" "/var/www/html"
          edit_nginx_config $nginx_default_path "listen" $(echo "80$php_version" | sed "s/\.//g")
          edit_nginx_config $nginx_default_path "fastcgi_pass" "unix:$php_listen_sock"
     done
     common_all_server reload
     for php_version in $(echo $php_versions | sed 's/|/ /g'); do
          echo "Default PHP-$php_version Listen: 0.0.0.0:$(echo "80$php_version" | sed "s/\.//g")"
     done
}

case "$1" in

install)
     echo "Start Install"
     init_env
     echo "Install MySql"
     install_mysql
     echo "Install PHP$php_versions"
     install_php
     echo "Install Nginx"
     install_nginx
     echo "Config Nginx & PHP$php_versions"
     init_conf_nginx_php
     echo "Install Composer"
     install_composer
     echo "Finish Install!"
     ;;
server)
     echo "$2 Server!"
     common_all_server $2
     ;;
*)
     echo "$0 install"
     echo "$0 server [start|stop|reload]"
     ;;

esac

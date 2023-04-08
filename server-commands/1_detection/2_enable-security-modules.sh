#!/usr/bin/bash

# enable Apache security modules
a2enmod security2 log_forensic log_debug

# restart Apache
systemctl restart apache2
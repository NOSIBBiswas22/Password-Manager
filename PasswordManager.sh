#!/bin/bash

password_file="passwords.txt"
encryption_key="-iter 100000 -keysize 256 -salt -1"

# Function to encrypt a password
encrypt_password() {
    local password="$1"
    echo "$password" | openssl enc -aes-256-cbc -a -salt -pass pass:"$encryption_key"
}

# Function to decrypt a password
decrypt_password() {
    local encrypted_password="$1"
    echo "$encrypted_password" | openssl enc -d -aes-256-cbc -a -salt -pass pass:"$encryption_key"
}

create_password_file_if_not_exist() {
    if [ ! -e "$password_file" ]; then
        touch "$password_file"
        echo "admin:" >> "$password_file"
        echo "code:" >> "$password_file"
    fi

    if grep -q "^admin:" "$password_file"; then
        verify_admin_password
    else
        echo "Admin password not found. Setting admin password."
        read -s -p "Enter new admin password: " new_admin_password
        encrypted_password=$(encrypt_password "$new_admin_password")
        echo "admin:$encrypted_password" >> "$password_file"
        echo -e "\n\033[1;32mAdmin password set. Please run the script again to log in.\033[0m\n"
        exit 0
    fi
}

# Function for animated loading message
loadmsg() {
    local spin="/-\|"
    local index=0
    local duration=$2

    echo -e
    for ((i = 0; i < duration; i++)); do
        printf "\r\033[34m$1... %c\033[0m" "${spin:index++%${#spin}:1}"
        sleep 0.1
    done

    printf "\r%*s\r" "$(tput cols)" ""
}

# Function to add a password
add_password() {
    sleep 0.3
    echo -e "\033[34m"
    read -p "Enter website/service name: " website
    echo -e "\033[0m"  # Reset color after user input1

    if grep -q "^$website:" "$password_file"; then
        echo -e "\n"
        loadmsg "Searching....." 20
        echo -e "\033[1;31mPassword for $website already exists. Cannot overwrite.\033[0m\n"
        sleep 4
        clear
    else
        sleep 0.5
        read -s -p "Enter password: " password
        encrypted_password=$(encrypt_password "$password")
        echo "$website:$encrypted_password" >> "$password_file"
        echo -e "\n"
        loadmsg "Adding....." 20
        echo -e "\033[1;32mPassword added for $website\033[0m\n"
        sleep 4
        clear
    fi
}

# Function to view passwords
view_passwords() {
    clear
    sleep 0.3
    echo -e "\033[34m"
    read -p "Enter website/service name to retrieve password: " search_website
    echo -e "\033[0m"  # Reset color after user input
    
    password_found=$(grep -w "^$search_website" "$password_file" | cut -d ':' -f 2)
    decrypted_password=$(decrypt_password "$password_found")

    if [ -n "$decrypted_password" ]; then
        echo -e "\n"
        loadmsg "Searching....." 20
        echo -e "\n\033[1;34mWebsite or Service:\033[0m $search_website"
        echo -e "\033[1;34mPassword:\033[0m $decrypted_password"
        echo -e "\n"
    else
        echo -e "\n"
        loadmsg "Searching....." 20
        echo -e "\n\033[1;31mPassword not found for $search_website\033[0m"
        sleep 4
    fi
}

# Function to change a password
change_password() {
    echo -e "\033[34m"
    read -p "Enter website/service name to change password: " change_website
    echo -e "\033[0m"  # Reset color after user input

    if grep -q "^$change_website:" "$password_file"; then
        sleep 0.5
        read -s -p "Enter new password: " new_password
        encrypted_password=$(encrypt_password "$new_password")
        sed -i "s|^$change_website:.*$|$change_website:$encrypted_password|" "$password_file"
        echo -e "\n"
        loadmsg "Changing....." 20
        echo -e "\n\033[1;32mPassword changed for $change_website\033[0m\n"
        sleep 4
        clear
    else
        echo -e "\n"
        loadmsg "Searching....." 20
        echo -e "\n\033[1;31mPassword not found for $change_website. Cannot change.\033[0m\n"
        sleep 4
        clear
    fi
}

# Function to display all website and service names
show_all_services() {
    echo -e "\033[1;34mAll Website and Service Names\033[0m"
    awk -F: '/^[a-zA-Z0-9]+:/{print $1}' "$password_file" | sed 's/:$//'
    echo -e "\n"
}

# Function to change admin password
change_admin_password() {
    echo -e "\n\033[1;31mChange Admin Password\033[0m"

    read -s -p "Enter recovery code: " recovery_code
    stored_encrypted_recovery_code=$(awk -F: '/^code:/ {print $2}' "$password_file")

    # Decrypt the stored recovery code
    stored_recovery_code=$(decrypt_password "$stored_encrypted_recovery_code")

    if [ "$recovery_code" == "$stored_recovery_code" ]; then
        echo -e "\n\033[1;34mPassword change process initiated...\033[0m"
        sleep 1
        echo -e "\n\033[1;34mVerifying recovery code...\033[0m"
        sleep 1
        read -s -p "Enter new admin password: " new_admin_password
        encrypted_password=$(encrypt_password "$new_admin_password")
        
        # Backup the old admin password
        old_admin_password=$(awk -F: '/^admin:/ {print $2}' "$password_file")

        # Update the admin password
        sed -i "s|^admin:.*$|admin:$encrypted_password|" "$password_file"

        # Log the password change
        echo "Admin password changed. Previous password: $old_admin_password" >> "$password_file"
        
        echo -e "\n\033[1;32mAdmin password changed successfully.\033[0m\n"
    else
        echo -e "\n\033[1;31mIncorrect recovery code. Password not changed.\033[0m\n"
    fi
}


# Function to verify admin password
verify_admin_password() {
    read -s -p "Enter admin password: " entered_password
    stored_admin_encrypted_password=$(awk -F: '/^admin:/ {print $2}' "$password_file")
    echo -e "\n"
    loadmsg "Verifying....." 16

    # Decrypt the stored admin password
    stored_admin_password=$(decrypt_password "$stored_admin_encrypted_password")

    if [ "$entered_password" == "$stored_admin_password" ]; then
        echo -e "\n\033[1;32mAdmin access granted. Welcome!\033[0m\n"
    else
        clear
        echo -e "\n\033[1;31mIncorrect admin password.\033[0m\n"
        read -p "Do you want to change the admin password? (y/n): " change_password_choice

        if [ "$change_password_choice" == "y" ]; then
            change_admin_password
            verify_admin_password
        else
            echo -e "\033[1;31mExiting.\033[0m"
            exit 1
        fi
    fi
    clear
}

# Initialize
clear
loadmsg "Starting" 20
echo -e "\033[1;34mPassword Manager\033[0m\n"
create_password_file_if_not_exist

# Main menu loop
while true; do
    echo -e "\033[1;34mMain Menu\033[0m\n"
    echo "1. Add Password"
    echo "2. View Passwords"
    echo "3. Change Password"
    echo "4. Show All Website and Service Names"
    echo "5. Exit"
    echo -e "\033[34m"
    read -p "Enter your choice: " choice
    echo -e "\033[0m"  # Reset color after user input

    case $choice in
        1) add_password ;;
        2) view_passwords ;;
        3) change_password ;;
        4) show_all_services ;;
        5) echo -e "\n\033[1;32mExiting Password Manager. Goodbye!\033[0m\n"; exit 0 ;;
        *) echo -e "\n\033[1;31mInvalid choice. Please enter a valid option.\033[0m" ;;
    esac
done

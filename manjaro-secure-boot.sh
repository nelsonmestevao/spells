#!/bin/sh

echo "Installing efitools & sbsigntools"
#sudo man pacman -Syu efitools
#sudo man pacman -Syu sbsigntools
sudo pacman -Syu efitools
sudo pacman -Syu sbsigntools
echo "Installation Complete. efitools & sbsigntools have installed"

echo "Creating folder \"Secure_Boot_Key\" in Home directory"
mkdir -p ~/Secure_Boot_Key/backup_key

echo "Creating Backups for old keys in \"back_up\" folder"
#Backup old keys
cd ~/Secure_Boot_Key/backup_key || exit
efi-readvar -v PK -o old_PK.esl
efi-readvar -v KEK -o old_KEK.esl
efi-readvar -v db -o old_db.esl
efi-readvar -v dbx -o old_dbx.esl


cd ~/Secure_Boot_Key || exit
echo "
Create a GUID for owner identification:"
#Create a GUID for owner identification:
uuidgen --random > GUID.txt

echo "
Creating Platform key:"
#Platform key:
openssl req -newkey rsa:4096 -nodes -keyout PK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Platform Key/" -out PK.crt
openssl x509 -outform DER -in PK.crt -out PK.cer
cert-to-efi-sig-list -g "$(cat GUID.txt)" PK.crt PK.esl
sign-efi-sig-list -g "$(cat GUID.txt)" -k PK.key -c PK.crt PK PK.esl PK.auth

#Sign an empty file to allow removing Platform Key when in "User Mode":
sign-efi-sig-list -g "$(cat GUID.txt)" -c PK.crt -k PK.key PK /dev/null rm_PK.auth

echo "
Creating Key Exchange Key:"
#Key Exchange Key:
openssl req -newkey rsa:4096 -nodes -keyout KEK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Key Exchange Key/" -out KEK.crt
openssl x509 -outform DER -in KEK.crt -out KEK.cer
cert-to-efi-sig-list -g "$(cat GUID.txt)" KEK.crt KEK.esl
sign-efi-sig-list -g "$(cat GUID.txt)" -k PK.key -c PK.crt KEK KEK.esl KEK.auth

echo "
Creating Signature Database key:"
#Signature Database key:
openssl req -newkey rsa:4096 -nodes -keyout db.key -new -x509 -sha256 -days 3650 -subj "/CN=my Signature Database key/" -out db.crt
openssl x509 -outform DER -in db.crt -out db.cer
cert-to-efi-sig-list -g "$(cat GUID.txt)" db.crt db.esl
sign-efi-sig-list -g "$(cat GUID.txt)" -k KEK.key -c KEK.crt db db.esl db.auth

#Replace keys : if you wanted to replace your db key with a new one:
#cert-to-efi-sig-list -g "$(cat GUID.txt)" new_db.crt new_db.esl
#sign-efi-sig-list -g "$(cat GUID.txt)" -k KEK.key -c KEK.crt db new_db.esl new_db.auth

#Add Key : If instead of replacing your db key, you want to add another one to the Signature Database
#sign-efi-sig-list -a -g "$(cat GUID.txt)" -k KEK.key -c KEK.crt db new_db.esl new_db.auth

echo "
Signing EFI binaries"
#Signature Database key:
#Signing EFI binaries
sudo sbsign --key ~/Secure_Boot_Key/db.key --cert ~/Secure_Boot_Key/db.crt --output /boot/vmlinuz-* /boot/vmlinuz-*
sudo sbsign --key ~/Secure_Boot_Key/db.key --cert ~/Secure_Boot_Key/db.crt --output /boot/efi/EFI/boot/bootx64.efi /boot/efi/EFI/boot/bootx64.efi


echo "
Creating Pacman Hook fro auto signing on updates"
sudo mkdir -p /etc/pacman.d/hooks
sudo cp /usr/share/libalpm/hooks/90-mkinitcpio-install.hook /etc/pacman.d/hooks/90-mkinitcpio-install.hook

sudo mkdir -p /usr/local/share/libalpm/scripts/
sudo cp /usr/share/libalpm/scripts/mkinitcpio-install /usr/local/share/libalpm/scripts/mkinitcpio-install


#com=" "
#while [ $com != "done" ]
#do
    echo "
# ----- # ----- # ---- #
Have to do by myself =
Create a new tab in terminal for ease.

sudo nano /etc/pacman.d/hooks/90-mkinitcpio-install.hook
replace : Exec = /usr/share/libalpm/scripts/mkinitcpio-install
with : Exec = /usr/local/share/libalpm/scripts/mkinitcpio-install

sudo nano /usr/local/share/libalpm/scripts/mkinitcpio-install
replace : install -Dm644 \"\${line}\" \"/boot/vmlinuz-\${pkgbase}\"
with : sbsign --key ~/Secure_Boot_Key/db.key --cert ~/Secure_Boot_Key/db.crt --output \"/boot/vmlinuz-\${pkgbase}\" \"\${line}\"
"
#    echo "Write \"done\""
#    read com
#done

file=/etc/pacman.d/hooks/90-mkinitcpio-install.hook
old="Exec = /usr/share/libalpm/scripts/mkinitcpio-install"
new="Exec = /usr/local/share/libalpm/scripts/mkinitcpio-install"
sudo cp $file $file.bak
cat $file | sed "s|$old|$new|" | sudo tee $file


file=/usr/local/share/libalpm/scripts/mkinitcpio-install
old="install -Dm644 \"\${line}\" \"/boot/vmlinuz-\${pkgbase}\""
new="sbsign --key ~/Secure_Boot_Key/db.key --cert ~/Secure_Boot_Key/db.crt --output \"/boot/vmlinuz-\${pkgbase}\" \"\${line}\""
sudo cp $file $file.bak
cat $file | sed "s|$old|$new|" | sudo tee $file


echo "Downloading Microsoft Keys and preparing them"

#wget https://www.microsoft.com/pkiops/certs/MicWinProPCA2011_2011-10-19.crt
curl -O https://www.microsoft.com/pkiops/certs/MicWinProPCA2011_2011-10-19.crt
curl -O https://www.microsoft.com/pkiops/certs/MicCorUEFCA2011_2011-06-27.crt
sbsiglist --owner 77fa9abd-0359-4d32-bd60-28f4e78f784b --type x509 --output MS_Win_db.esl MicWinProPCA2011_2011-10-19.crt
sbsiglist --owner 77fa9abd-0359-4d32-bd60-28f4e78f784b --type x509 --output MS_UEFI_db.esl MicCorUEFCA2011_2011-06-27.crt
cat MS_Win_db.esl MS_UEFI_db.esl > MS_db.esl
sign-efi-sig-list -a -g 77fa9abd-0359-4d32-bd60-28f4e78f784b -k KEK.key -c KEK.crt db MS_db.esl add_MS_db.auth


mkdir -p ~/Secure_Boot_Key/Keys/{db,dbx,KEK,PK,Win}
cp ~/Secure_Boot_Key/PK.auth ~/Secure_Boot_Key/Keys/PK || exit
cp ~/Secure_Boot_Key/KEK.auth ~/Secure_Boot_Key/Keys/KEK || exit
cp ~/Secure_Boot_Key/db.auth ~/Secure_Boot_Key/Keys/db || exit
cp ~/Secure_Boot_Key/add_MS_db.auth ~/Secure_Boot_Key/Keys/Win || exit


echo "Installing Grub with TPM module"
sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=manjaro --modules="tpm"
sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=manjaro --modules="tpm" --disable-shim-lock
sudo sbsign --key ~/Secure_Boot_Key/db.key --cert ~/Secure_Boot_Key/db.crt --output /boot/efi/EFI/Manjaro/grubx64.efi /boot/efi/EFI/Manjaro/grubx64.efi
sudo update-grub



com=" "
while [ "$com" != "done" ]
do
    echo "
Now, Go to your UEFI-BIOS to manually enrool the keys
Copy \"Keys\" folder with \"*.auth\" keys to a FAT formatted file system (you can use EFI system partition).
Then enroll :
    Platform Key (PK)       : Keys/PK/PK.auth
    Key Exchange Key (KEK)  : Keys/KEK/KEK.auth
    Signature Database (db) : Keys/db/db.auth
    #Then Append Signature Database (db) with Microsoft key.
    Signature Database (db) : Keys/Win/add_MS_db.auth  {Append}

#To copy you can use,
cp -r ~/Secure_Boot_Key/Keys /Location
"
    echo "Write \"done\""
    read -r com
done

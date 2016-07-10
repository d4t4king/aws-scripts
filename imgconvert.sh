#!/bin/bash

#GALLERY_DIR='/usr/share/nginx/html/gallery'
BACKUP_DIR='/root/img_backup'

GALLERY_DIR="$1"

for P in `ls -1 "$GALLERY_DIR"`; do
	EXT=$(echo $P | awk -F. '{ print $NF }')
	#echo "EXT: $EXT"
	if ! [[ "$EXT" =~ (jpg|png|gif|tiff|bmp) ]]; then continue; fi
	echo -n "$P:	"
	RES=`exiftool "$GALLERY_DIR/$P" | grep 'Image Size' | awk '{ print $4 }'`
	case $RES in
		"456x256")
			echo "Small Portrait"
			cp -vr "$GALLERY_DIR/$P" "$BACKUP_DIR/$P"
			convert "$BACKUP_DIR/$P" -resize 1024x576 "$GALLERY_DIR/$P"
			;;
		"256x455")
			echo "Small Landscape"
			cp -vr "$GALLERY_DIR/$P" "$BACKUP_DIR/$P"
			convert "$BACKUP_DIR/$P" -resize 576x1024 "$GALLERY_DIR/$P"
			;;
		"1593x1195")
			echo "Medium Phone Landscape (Horizontal)"
			cp -vr "$GALLERY_DIR/$P" "$BACKUP_DIR/$P"
			convert "$BACKUP_DIR/$P" -resize 64% "$GALLERY_DIR/$P"
			;;
		"2560x1440")
			echo "Medium Landscap (Horizontal)"
			cp -vr "$GALLERY_DIR/$P" "$BACKUP_DIR/$P"
			convert "$BACKUP_DIR/$P" -resize 1024x576 "$GALLERY_DIR/$P"
			;;
		"5456x3046")
			echo "Enormous Landscape (Horizontal)"
			cp -vr "$GALLERY_DIR/$P" "$BACKUP_DIR/$P"
			convert "$BACKUP_DIR/$P" -resize 20% "$GALLERY_DIR/$P"
			;;
		"5934x3956")
			echo "Enormous Landscape (Horizontal)"
			cp -vr "$GALLERY_DIR/$P" "$BACKUP_DIR/$P"
			convert "$BACKUP_DIR/$P" -resize 20% "$GALLERY_DIR/$P"
			;;
		"5809x3873")
			echo "Enormous Landscape (Horizontal)"
			cp -vr "$GALLERY_DIR/$P" "$BACKUP_DIR/$P"
			convert "$BACKUP_DIR/$P" -resize 20% "$GALLERY_DIR/$P"
			;;
		"6000x4000")
			echo "Enormous Landscape (Horizontal)"
			cp -vr "$GALLERY_DIR/$P" "$BACKUP_DIR/$P"
			convert "$BACKUP_DIR/$P" -resize 20% "$GALLERY_DIR/$P"
			;;
		"4000x6000")
			echo "Enormous Portrait (Vertical)"
			cp -vr "$GALLERY_DIR/$P" "$BACKUP_DIR/$P"
			convert "$BACKUP_DIR/$P" -resize 20% "$GALLERY_DIR/$P"
			;;
		"5312x2988")
			echo "X-Large Phone Landscape (Horizontal)"
			cp -vr "$GALLERY_DIR/$P" "$BACKUP_DIR/$P"
			convert "$BACKUP_DIR/$P" -resize 20% "$GALLERY_DIR/$P"
			;;
		"2988x5312")
			echo "X-Large Phone Portrait (Vertical)"
			cp -vr "$GALLERY_DIR/$P" "$BACKUP_DIR/$P"
			convert "$BACKUP_DIR/$P" -resize 20% "$GALLERY_DIR/$P"
			;;
		"2448x3264")
			echo "Large portrait!"
			cp -vf "$GALLERY_DIR/$P" "$BACKUP_DIR/$P"
			convert "$BACKUP_DIR/$P" -resize 768x1024 "$GALLERY_DIR/$P"
			;;
		"3264x2448")
			echo "Large landscape!"
			cp -vf "$GALLERY_DIR/$P" "$BACKUP_DIR/$P"
			convert "$BACKUP_DIR/$P" -resize 1024x768 "$GALLERY_DIR/$P"
			;;
		*)
			echo " ${RES}"
			;;
	esac
done

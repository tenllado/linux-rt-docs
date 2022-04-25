#!/bin/bash


for src in ../actividades/*.md;
do
	fname=$(basename $src)
	dest=${fname%md}html
	echo "${src} --> ${dest}"
	pandoc ${src} -N --self-contained  --template pandoc-templates/toc-sidebarL-title.html-template.html --toc  -o ${dest}
done

for src in $(ls ../actividades/*.md | grep -v index.md);
do
	fname=$(basename $src)
	dest=${fname%md}pdf
	echo "${src} --> ${dest}"
	pandoc ${src} -N --self-contained  -o ${dest}
done


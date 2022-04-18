#!/bin/bash
cp ./theme ./theme-local.setup ./*.html -r ./public/
cp ./articles/theme ./articles/style ./articles/theme-local.setup ./articles/style-local.setup ./articles/*.html ./articles/*.pdf ./articles/*.org -r ./public/articles/
cp ./media -r ./public/
cp ./articles/media -r ./public/

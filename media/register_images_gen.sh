pdflatex register_images.tex -f
# for i in register_images.pdf; do sips -s format png $i --out $i.png; done
gs -dNOPAUSE -sDEVICE=jpeg -r200 -dJPEGQ=100 -sOutputFile=register_images-%02d.jpg "register_images.pdf" -dBATCH

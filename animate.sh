echo -e "\033[?25l" && clear && ruby mathison.rb | while read -r line; do echo -e "\033[2H $line"; sleep 0.1; done && echo -e "\033[?25h"

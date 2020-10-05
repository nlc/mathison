echo -e "\033[?25l" && clear && ruby turing.rb | while read -r line; do echo -e "\033[2H $line"; sleep 0.5; done && echo -e "\033[?25h"

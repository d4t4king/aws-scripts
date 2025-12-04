alias ls='ls --color=auto'
alias ll='ls -lA'
alias rm='rm -i'
alias cp='cp -i'

function getip4() {
	ip -o addr | grep "en[ps]" | grep "inet\b" | awk '{ print $4 }'
}

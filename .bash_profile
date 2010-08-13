# ~/.bash_profile
# Carlos Amedee
# Grabbed an idea or two from Jlilly

if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi


#Paths
PATH=$PATH:$HOME/bin


#App settings
export GREP_OPTIONS='--color=auto'
export GREP_COLOR='1;31'
export HISTCONTROL=erasedups  # Ignore duplicate entries in history
export HISTSIZE=10000         # Increases size of history
shopt -s histappend        # Append history instead of overwriting
shopt -s cdspell           # Correct minor spelling errors in cd command
shopt -s dotglob           # includes dotfiles in pathname expansion
shopt -s checkwinsize      # If window size changes, redraw contents
shopt -s cmdhist           # Multiline commands are a single command in history.

#ALAIS

# set some OS specific definitions
case $MACHTYPE in
    *redhat*)

    ;;
    *linux*)

    ;;
    *darwin*)

    ;;
    *cygwin*)

    ;;
  *)
    ;;
esac


#Prompt
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\n\$ '

#PS1='\[\033[0;36m\]\d \[\033[00m\]- \[\033[0;37m\]\T \[\033[1;37m\]\u\[\033[0;39m\]@\[\033[1;35m\]\h\[\033[0;33m\] \w\[\033[00m\]: '

#PS1="\[\033[0;33m\][\!]\`if [[ \$? = "0" ]]; then echo "\\[\\033[32m\\]"; else echo "\\[\\033[31m\\]"; fi\`[\u.\h: \`if [[ `pwd|wc -c|tr -d " "` > 18 ]]; then echo "\\W"; else echo "\\w"; fi\`]\$\[\033[0m\] "; echo -ne "\033]0;`hostname -s`:`pwd`\007"'


#if [ "$TERM" = "linux" ]
#then
  #we're on the system console or maybe telnetting in
#  export PS1="\[\e[32;1m\]\u@\H > \[\e[0m\]"
#else
  #we're not on the console, assume an xterm
#  export PS1="\[\e]2;\u@\H \w\a\e[32;1m\]>\[\e[0m\] " 
#fi


#Custom
#From jlilly
extract () {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)        tar xjf $1        ;;
            *.tar.gz)         tar xzf $1        ;;
            *.bz2)            bunzip2 $1        ;;
            *.rar)            unrar x $1        ;;
            *.gz)             gunzip $1         ;;
            *.tar)            tar xf $1         ;;
            *.tbz2)           tar xjf $1        ;;
            *.tgz)            tar xzf $1        ;;
            *.zip)            unzip $1          ;;
            *.Z)              uncompress $1     ;;
            *)                echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

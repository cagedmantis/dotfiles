# ~/.bash_profile
# Carlos Amedee
# www.amedee.net

export PATH=$PATH:$HOME/bin

if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

# set some OS specific definitions
case $MACHTYPE in
    *redhat*)
        echo "Rehat box"
    ;;
    *linux*)
        echo "Linux box"
    ;;
    *darwin*)
        echo "OS X box"
    ;;
    *cygwin*)
        echo "Windows box"
    ;;
    *)
    ;;
esac

export PATH=/usr/local/sbin:$PATH
export PATH=/usr/local/Cellar/ruby/1.9.3-p194/bin:$PATH


##
# Your previous /Users/camedee/.bash_profile file was backed up as /Users/camedee/.bash_profile.macports-saved_2012-08-09_at_23:34:39
##

# MacPorts Installer addition on 2012-08-09_at_23:34:39: adding an appropriate PATH variable for use with MacPorts.
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
# Finished adapting your PATH environment variable for use with MacPorts.


[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

fortune | cowsay | lolcat

# ~/.bash_profile
# Carlos Amedee

export PATH=$PATH:$HOME/bin
export PATH="$PATH:/usr/local/smlnj-110.76/bin"

DROPBOX=`which dropbox`
RUNNING=`$DROPBOX running`

# Grabed this from apg
if [[ $? -eq 0 ]]
then
    $DROPBOX start
fi

if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

if [ -f ~/.bash_profile_ps ]; then
    source ~/.bash_profile_ps
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

# MacPorts Installer addition on 2012-08-09_at_23:34:39: adding an appropriate PATH variable for use with MacPorts.
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
# Finished adapting your PATH environment variable for use with MacPorts.


[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

fortune | cowsay | lolcat

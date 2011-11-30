# ~/.bash_profile
# Carlos Amedee
# www.amedee.net

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



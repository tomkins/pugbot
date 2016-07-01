###########################################################################
# Configuration here                                                      #
###########################################################################

putlog "Tribes Mixed Bot Loading..."
package require textutil 0.7

namespace eval tribesMixedBot {
    variable signups
    variable activemixed
    if {![info exists signups]} {
        array set signups {}
    }
    if {![info exists activemixed]} {
        array set activemixed {}
    }

    proc tamixed:topic { channel } {
        variable signups
        variable activemixed

        # Must be an op to update
        if {![botisop $channel]} {
            return
        }

        set chan [string tolower $channel]

        # Set the topic
        if {![info exists activemixed($chan)]} {
            putserv "TOPIC $channel :No mixed currently active - !start to start a new game"
        } else {
            set playercount [llength $signups($chan)]
            set playermax $activemixed($chan)
            set players $signups($chan)
            putserv "TOPIC $channel :\[$playercount/$playermax\]: $players"
        }
    }

    ###########################################################################
    # !add
    proc bindpub:add { nick uhost handle channel text } {
        variable signups
        variable activemixed

        # Must be a mixed channel
        if {![channel get $channel tribesmixed]} {
            return
        }

        set chan [string tolower $channel]

        # Must have an active mixed
        if {![info exists activemixed($chan)]} {
            putserv "NOTICE $nick :No mixed currently active."
            return
        }

        # Must not be signed up already
        if {[lsearch -exact $signups($chan) $nick] > -1} {
            putserv "NOTICE $nick :You've already signed up!"
            return
        }

        # Can't be full
        if {[llength $signups($chan)] >= $activemixed($chan)} {
            putserv "NOTICE $nick :This game is full, try again later!"
            return
        }

        lappend signups($chan) $nick

        set playercount [llength $signups($chan)]
        set playermax $activemixed($chan)
        set players $signups($chan)

        putserv "PRIVMSG $channel :\[$playercount/$playermax\] $nick is now signed up!"
        tamixed:topic $channel
    }

    bind pub - !add [namespace current]::bindpub:add
    ###########################################################################

    ###########################################################################
    # !del
    proc bindpub:del { nick uhost handle channel text } {
        variable signups
        variable activemixed

        # Must be a mixed channel
        if {![channel get $channel tribesmixed]} {
            return
        }

        set chan [string tolower $channel]

        # Must have an active mixed
        if {![info exists activemixed($chan)]} {
            putserv "NOTICE $nick :No mixed currently active."
            return
        }

        set nick_position [lsearch -exact $signups($chan) $nick]

        # Must be signed up already
        if {$nick_position == -1} {
            putserv "NOTICE $nick :You've haven't signed up!"
            return
        }

        set signups($chan) [lreplace $signups($chan) $nick_position $nick_position]

        set playercount [llength $signups($chan)]
        set playermax $activemixed($chan)
        set players $signups($chan)
        putserv "PRIVMSG $channel :\[$playercount/$playermax\] $nick has abandoned us!"
        tamixed:topic $channel
    }

    bind pub - !del [namespace current]::bindpub:del
    ###########################################################################



    ###########################################################################
    # !remove
    proc bindpub:remove { nick uhost handle channel text } {
        variable signups
        variable activemixed

        # Must be a mixed channel
        if {![channel get $channel tribesmixed]} {
            return
        }

        # Must be an op
        if {![isop $nick $channel]} {
            putserv "NOTICE $nick :Access denied - must be a channel operator."
            return
        }

        set chan [string tolower $channel]

        # Must have an active mixed
        if {![info exists activemixed($chan)]} {
            putserv "NOTICE $nick :No mixed currently active."
            return
        }

        set nick_position [lsearch -exact $signups($chan) $text]

        # Must be signed up already
        if {$nick_position == -1} {
            putserv "NOTICE $nick :$text hasn't signed up!"
            return
        }

        set signups($chan) [lreplace $signups($chan) $nick_position $nick_position]

        set playercount [llength $signups($chan)]
        set playermax $activemixed($chan)
        set players $signups($chan)
        putserv "PRIVMSG $channel :\[$playercount/$playermax\] $text has been removed by $nick!"
        tamixed:topic $channel
    }

    bind pub - !remove [namespace current]::bindpub:remove
    ###########################################################################

    ###########################################################################
    # !status
    proc bindpub:status { nick uhost handle channel text } {
        variable signups
        variable activemixed

        # Must be a mixed channel
        if {![channel get $channel tribesmixed]} {
            return
        }

        set chan [string tolower $channel]

        # Must have an active mixed
        if {![info exists activemixed($chan)]} {
            putserv "NOTICE $nick :No mixed currently active."
            return
        }

        set playercount [llength $signups($chan)]
        set playermax $activemixed($chan)
        set players $signups($chan)
        putserv "NOTICE $nick :Players \[$playercount/$playermax\]: $players"
    }

    bind pub - !status [namespace current]::bindpub:status
    ###########################################################################

    ###########################################################################
    # !start
    proc bindpub:start { nick uhost handle channel text } {
        variable activemixed
        variable signups

        # Must be a mixed channel
        if {![channel get $channel tribesmixed]} {
            return
        }

        set chan [string tolower $channel]

        # Must not already have an active mixed
        if {[info exists activemixed($chan)]} {
            putserv "NOTICE $nick :Mixed already active!"
            return
        }

        set players 14

        if {[string is integer $text]} {
            set players $text
        }

        set activemixed($chan) $players
        set signups($chan) {}

        putserv "PRIVMSG $channel :Starting mixed signups for $players players"
        tamixed:topic $channel
    }

    bind pub - !start [namespace current]::bindpub:start
    ###########################################################################

    ###########################################################################
    # !finish
    proc bindpub:finish { nick uhost handle channel text } {
        variable activemixed
        variable signups

        # Must be a mixed channel
        if {![channel get $channel tribesmixed]} {
            return
        }

        # Must be an op
        if {![isop $nick $channel]} {
            putserv "NOTICE $nick :Access denied - must be a channel operator."
            return
        }

        set chan [string tolower $channel]

        # Must have an active mixed
        if {![info exists activemixed($chan)]} {
            putserv "NOTICE $nick :No mixed currently active."
            return
        }

        unset activemixed($chan)
        unset signups($chan)
        putserv "PRIVMSG $channel :Game ended by $nick"
        tamixed:topic $channel
    }

    bind pub - !finish [namespace current]::bindpub:finish
    ###########################################################################

    ###########################################################################
    # !spam
    proc bindpub:spam { nick uhost handle channel text } {
        variable activemixed
        variable signups

        # Must be a mixed channel
        if {![channel get $channel tribesmixed]} {
            return
        }

        # Must be an op
        if {![isop $nick $channel]} {
            putserv "NOTICE $nick :Access denied - must be a channel operator."
            return
        }

        set chan [string tolower $channel]

        # Must have an active mixed
        if {![info exists activemixed($chan)]} {
            putserv "NOTICE $nick :No mixed currently active."
            return
        }

        set basemsg "PRIVMSG $channel :\002$nick\002 spamming: "
        set maxlength [expr 400-[string length $basemsg]]
        foreach nicklist [split [::textutil::adjust [join [chanlist $channel]] -length $maxlength] "\n"] {
            putserv "$basemsg$nicklist"
        }
    }

    bind pub - !spam [namespace current]::bindpub:spam
    ###########################################################################

    ###########################################################################
    # User join
    proc bind:join { nick uhost handle channel } {
        variable activemixed
        variable signups

        # Must be a mixed channel
        if {![channel get $channel tribesmixed]} {
            return
        }

        set chan [string tolower $channel]

        # Must have an active mixed
        if {![info exists activemixed($chan)]} {
            return
        }

        set playercount [llength $signups($chan)]
        set playermax $activemixed($chan)
        set players $signups($chan)

        if {$playercount < $playermax} {
            puthelp "NOTICE $nick :Welcome to $chan - signups for the next game are currently in progress, just type !add to sign up."
        } else {
            puthelp "NOTICE $nick :Welcome to $chan - the next game is currently full, wait for a new game to be started and use !add to sign up."
        }
        puthelp "NOTICE $nick :Players \[$playercount/$playermax\]: $players"
    }

    bind join - "*" [namespace current]::bind:join
    ###########################################################################
}

setudef flag tribesmixed
setudef flag tribesmixedtopic

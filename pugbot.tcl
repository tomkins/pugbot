###########################################################################
# Configuration here                                                      #
###########################################################################

putlog "Pickup Game Bot Loading..."
package require textutil 0.7

namespace eval pugbot {
    variable signups
    variable activegame
    if {![info exists signups]} {
        array set signups {}
    }
    if {![info exists activegame]} {
        array set activegame {}
    }

    proc pugbot:topic { channel } {
        variable signups
        variable activegame

        # Must be an op to update
        if {![botisop $channel]} {
            return
        }

        set chan [string tolower $channel]

        # Set the topic
        if {![info exists activegame($chan)]} {
            putserv "TOPIC $channel :No game currently active - !start to start a new game"
        } else {
            set playercount [llength $signups($chan)]
            set playermax $activegame($chan)
            set players $signups($chan)
            putserv "TOPIC $channel :\[$playercount/$playermax\]: $players"
        }
    }

    ###########################################################################
    # !add
    proc bindpub:add { nick uhost handle channel text } {
        variable signups
        variable activegame

        # Must be a game channel
        if {![channel get $channel pickupgame]} {
            return
        }

        set chan [string tolower $channel]

        # Must have an active game
        if {![info exists activegame($chan)]} {
            putserv "NOTICE $nick :No game currently active."
            return
        }

        # Must not be signed up already
        if {[lsearch -exact $signups($chan) $nick] > -1} {
            putserv "NOTICE $nick :You've already signed up!"
            return
        }

        # Can't be full
        if {[llength $signups($chan)] >= $activegame($chan)} {
            putserv "NOTICE $nick :This game is full, try again later!"
            return
        }

        lappend signups($chan) $nick

        set playercount [llength $signups($chan)]
        set playermax $activegame($chan)
        set players $signups($chan)

        putserv "PRIVMSG $channel :\[$playercount/$playermax\] $nick is now signed up!"
        pugbot:topic $channel
    }

    bind pub - !add [namespace current]::bindpub:add
    ###########################################################################

    ###########################################################################
    # !del
    proc bindpub:del { nick uhost handle channel text } {
        variable signups
        variable activegame

        # Must be a game channel
        if {![channel get $channel pickupgame]} {
            return
        }

        set chan [string tolower $channel]

        # Must have an active game
        if {![info exists activegame($chan)]} {
            putserv "NOTICE $nick :No game currently active."
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
        set playermax $activegame($chan)
        set players $signups($chan)
        putserv "PRIVMSG $channel :\[$playercount/$playermax\] $nick has abandoned us!"
        pugbot:topic $channel
    }

    bind pub - !del [namespace current]::bindpub:del
    ###########################################################################

    ###########################################################################
    # !remove
    proc bindpub:remove { nick uhost handle channel text } {
        variable signups
        variable activegame

        # Must be a game channel
        if {![channel get $channel pickupgame]} {
            return
        }

        # Must be an op
        if {![isop $nick $channel]} {
            putserv "NOTICE $nick :Access denied - must be a channel operator."
            return
        }

        set chan [string tolower $channel]

        # Must have an active game
        if {![info exists activegame($chan)]} {
            putserv "NOTICE $nick :No game currently active."
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
        set playermax $activegame($chan)
        set players $signups($chan)
        putserv "PRIVMSG $channel :\[$playercount/$playermax\] $text has been removed by $nick!"
        pugbot:topic $channel
    }

    bind pub - !remove [namespace current]::bindpub:remove
    ###########################################################################

    ###########################################################################
    # !status
    proc bindpub:status { nick uhost handle channel text } {
        variable signups
        variable activegame

        # Must be a game channel
        if {![channel get $channel pickupgame]} {
            return
        }

        set chan [string tolower $channel]

        # Must have an active game
        if {![info exists activegame($chan)]} {
            putserv "NOTICE $nick :No game currently active."
            return
        }

        set playercount [llength $signups($chan)]
        set playermax $activegame($chan)
        set players $signups($chan)
        putserv "NOTICE $nick :Players \[$playercount/$playermax\]: $players"
    }

    bind pub - !status [namespace current]::bindpub:status
    ###########################################################################

    ###########################################################################
    # !start
    proc bindpub:start { nick uhost handle channel text } {
        variable activegame
        variable signups

        # Must be a game channel
        if {![channel get $channel pickupgame]} {
            return
        }

        set chan [string tolower $channel]

        # Must not already have an active game
        if {[info exists activegame($chan)]} {
            putserv "NOTICE $nick :Mixed already active!"
            return
        }

        set players 14

        if {[string is integer $text]} {
            set players $text
        }

        set activegame($chan) $players
        set signups($chan) {}

        putserv "PRIVMSG $channel :Starting game signups for $players players"
        pugbot:topic $channel
    }

    bind pub - !start [namespace current]::bindpub:start
    ###########################################################################

    ###########################################################################
    # !finish
    proc bindpub:finish { nick uhost handle channel text } {
        variable activegame
        variable signups

        # Must be a game channel
        if {![channel get $channel pickupgame]} {
            return
        }

        # Must be an op
        if {![isop $nick $channel]} {
            putserv "NOTICE $nick :Access denied - must be a channel operator."
            return
        }

        set chan [string tolower $channel]

        # Must have an active game
        if {![info exists activegame($chan)]} {
            putserv "NOTICE $nick :No game currently active."
            return
        }

        unset activegame($chan)
        unset signups($chan)
        putserv "PRIVMSG $channel :Game ended by $nick"
        pugbot:topic $channel
    }

    bind pub - !finish [namespace current]::bindpub:finish
    ###########################################################################

    ###########################################################################
    # !spam
    proc bindpub:spam { nick uhost handle channel text } {
        variable activegame
        variable signups

        # Must be a game channel
        if {![channel get $channel pickupgame]} {
            return
        }

        # Must be an op
        if {![isop $nick $channel]} {
            putserv "NOTICE $nick :Access denied - must be a channel operator."
            return
        }

        set chan [string tolower $channel]

        # Must have an active game
        if {![info exists activegame($chan)]} {
            putserv "NOTICE $nick :No game currently active."
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
        variable activegame
        variable signups

        # Must be a game channel
        if {![channel get $channel pickupgame]} {
            return
        }

        set chan [string tolower $channel]

        # Must have an active game
        if {![info exists activegame($chan)]} {
            return
        }

        set playercount [llength $signups($chan)]
        set playermax $activegame($chan)
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

setudef flag pickupgame
setudef flag pickupgametopic

#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use encoding 'utf8';
use Date::Calc qw(Delta_Days);

my $mailingList		= 'talk\@domain.local';
my $store			= '/opt/kerio/mailserver/store';
my $mailLog			= $store . '/logs/mail.log';
my $memberList		= $store . '/lists/domain.local/talk/members';
my $dbLog			= './log.txt';
my $maxInactivity	= 30; # days

open(LOG, $mailLog) or die 'Cannot open mail.log file';
my @log = <LOG>;
close(LOG);

open(DB, "$dbLog") or &createDbLog;
open(DB, "$dbLog");
my @db = <DB>;
close(DB);

open(LIST, $memberList) or die 'Cannot open members list';
my @members = <LIST>;
close(LIST);

my %records  = ();
my $lastRecord;

# Load old records
foreach my $dline (@db) {
    chomp($dline);
    if($dline =~ /^#(.+)/) {
        $lastRecord = $1;
        next;
    }
    $dline =~ /(.+)\s(.+\s.+)/;
    my ($who, $date) = ($1, $2);
    $records{$who} = $date;
}

# Parse log
foreach my $lline (@log) {
    chomp($lline);
    $lline =~ /\[(.+)\]\sRecv\:\sQueue-ID\:\s(.+)\,\sService\:\s\w+\,\sFrom\:\s\<(.+)\>\,\sTo\:.+/;
    my ($date, $queueid, $from) = ($1, $2, $3);
    
    next if not $lline =~ /Recv\:/;
    next if not $lline =~ /To\:\s\<$mailingList\>/;
    next if &getDateAsNumber($lastRecord) >= &getDateAsNumber($date);

    $records{$from} = $date;
    $lastRecord = $date;
}

# Update db
open(DB, ">$dbLog") or die 'Cannot update db file';
print DB "#$lastRecord\n";
foreach my $record (sort(keys(%records))) {
    print DB "$record $records{$record}\n";
}
close(DB);

# Load members list
foreach my $mline (@members) {
    chomp($mline);
    my ($member, $name) = split(/;/, $mline);
    $records{$member} = 'NEVER';
}

# Check activity
my $today = qx(date +"%Y %m %d");
my @today = split(/ /, $today);
foreach my $line (keys(%records)) {
    if($records{$line} eq 'NEVER') {
        print "User $line never sent an email.\n";
        next;
    }
    my @userActivity = (&getPartFromDate('year',  &getDateAsNumber($records{$line})),
                        &getPartFromDate('month', &getDateAsNumber($records{$line})),
                        &getPartFromDate('day',   &getDateAsNumber($records{$line})));
    my $difference = Delta_Days(@userActivity, @today);
    print "User $line is inactive for $difference days.\n" if $difference > $maxInactivity;
}


sub getMonthByName() {
    my $month = shift;
    my %months = (
        'Jan' => '01',
        'Feb' => '02',
        'Mar' => '03',
        'Apr' => '04',
        'May' => '05',
        'Jun' => '06',
        'Jul' => '07',
        'Aug' => '08',
        'Sep' => '09',
        'Oct' => '10',
        'Nov' => '11',
        'Dec' => '12'
    );

    return $months{$month};
}

sub getDateAsNumber($) {
    my $date = shift;
    $date =~ /(..)\/(\w+)\/(....)\s(..)\:(..)\:(..)/;
    my ($day, $month, $year, $hour, $min, $sec) = ($1, &getMonthByName($2), $3, $4, $5, $6);
    
    return $year.$month.$day.$hour.$min.$sec;
}

sub getPartFromDate($) {
    my ($part, $date) = @_;
    $date =~ /(....)(..)(..)(..)(..)(..)/;
    my ($year, $month, $day) = ($1, $2, $3);

    return $year  if $part eq 'year';
    return $month if $part eq 'month';
    return $day   if $part eq 'day';
}

sub createDbLog() {
    open(DBL, ">>$dbLog") or die 'Cannot create db file';
    print DBL "\#01\/Jan\/1950 00\:00\:00\n";
    close(DBL);
}

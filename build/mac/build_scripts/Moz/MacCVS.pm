#!perl -w
package Moz::MacCVS;

# package Mac::Apps::MacCVS; this should really be the name of the package
# but due to our directory hierarchy in mozilla, I am not doing it

require 5.004;
require Exporter;

use strict;
use Exporter;

use vars qw($VERSION @ISA @EXPORT $MacCVSLib);

use Cwd;

use Mac::StandardFile;
use File::Basename;

@ISA				= qw(Exporter);
@EXPORT			= qw( new print checkout);
$VERSION = "1.00";

my($last_error) = 0;

# Architecture:
# cvs session object:
# name - session name
# session_file - session file
# 
# globals
# $MacCVSLib - location of MacCVS applescript library
#
# 

#
# utility routines
#

# just like Mac::DoAppleScript, 1 is success, 0 is failure
sub _myDoAppleScript($) 
{
	my($script) = @_;
	my $asresult = MacPerl::DoAppleScript($script);

	if ($asresult eq "0")
	{
		return 1;
	}
	else
	{
		my($error_string) = "Unknown error";
		my($error_code) = 0;

		if ($asresult =~ /^\"(.*)\.([0-9]+)\"$/)
		{
			$error_string = $1;
			$error_code = $2;
		}

		print STDERR "Error. Script returned '$error_string (error $error_code)\n";
		# print STDERR "AppleScript was: \n $script \n";
		$last_error = $error_code;
		return 0;
	}
}

# get the full path to this module
sub _getPathToMe()
{
	# this can be a relative or absolute path. If relative, is relative
	# to the running script ($0)
	my($my_path) = $INC{"Moz/MacCVS.pm"};
	
	if (substr($my_path, 0, 1) eq ":")	# relative path
	{
		$my_path = dirname($0).$my_path;
	}
	
	return $my_path;
}

# _useMacCVSLib
# returns 1 on success
# Search the include path for the file called MacCVSLib
sub _useMacCVSLib() 
{
	unless (defined($MacCVSLib) && ($MacCVSLib ne ""))
	{
		my($libname) = "MacCVSLib";
		
		my($my_path) = _getPathToMe();
		
		# try in the same directory as this module
		my($c) = dirname($my_path).":".$libname;
		if ( -e $c)
		{
			$MacCVSLib = $c;
			return 1;
		}
		
		# try the directory we were run from
		$c = dirname($0) . ":" . $libname;
		if ( -e $c)
		{
			$MacCVSLib = $c;
			return 1;
		}

		# now search the include directories
		foreach (@INC)
		{
			unless ( m/^Dev:Pseudo/ ) # This is some bizarre MacPerl special-case directory
			{
				$c = $_ . $libname;
				if (-e $c)
				{
					$MacCVSLib = $c;
					return 1;
				}
			}
		}

		die "Error: MacCVSLib could not be found!";
	}
	return 1;
}


#
# Session object methods
#

sub new
{
	my ( $proto, $session_file) = @_;
	my $class = ref($proto) || $proto;
	my $self = {};

	if ( defined($session_file) && ( -e $session_file) )
	{
		$self->{"name"} = basename( $session_file );
		$self->{"session_file"} = $session_file;
		bless $self, $class;
		return $self;
	}
	else
	{
		print STDERR "MacCVS->new cvs file < $session_file > does not exist\n";
		return;
	}
}

# makes sure that the session is open
# assertSessionOpen()
# returns 1 on success
sub assertSessionOpen()
{
	my ($self) = shift;
	
	_useMacCVSLib() || die "Error: Could not load MacCVSLib\n";
	$last_error = 0;

	my $script = <<END_OF_APPLESCRIPT;
	tell (load script file "$MacCVSLib") to OpenSession("$self->{session_file}")
END_OF_APPLESCRIPT
	return _myDoAppleScript($script);
}

# prints the cvs object, used mostly for debugging
sub print
{
	my($self) = shift;
		$last_error = 0;
	print "MacCVS:: name: ", $self->{name}, " session file: ", $self->{session_file}, "\n";
}

# checkout( self, module, revision, date)
# MacCVS checkout command
# returns 1 on success.
sub checkout()
{
	my($self, $module, $revision, $date ) = @_;
	unless( defined ($module) ) { $module = ""; } # get rid of the pesky undefined warnings
	unless( defined ($revision) ) { $revision = ""; }
	unless( defined ($date) ) { $date = ""; }

	$last_error = 0;
		
	$self->assertSessionOpen() || die "Error: failed to open MacCVS session file at $self->{session_file}\n";
	
	my($revstring) = ($revision ne "") ? $revision : "(none)";
	my($datestring) = ($date ne "") ? $date : "(none)";
	
	print "Checking out $module with revision $revstring, date $datestring\n";
	
	my $script = <<END_OF_APPLESCRIPT;
	tell (load script file "$MacCVSLib") to Checkout given sessionName:"$self->{name}", module:"$module", revision:"$revision", date:"$date"
END_OF_APPLESCRIPT
	return _myDoAppleScript($script);
}

sub getLastError()
{
	return $last_error;
}

1;
=pod

=head1 NAME

MacCVS - Interface to MacCVS

=head1 SYNOPSIS

	use MacCVS;
	$session = MacCVS->new( <session_file_path>) || die "cannot create session";
	$session->checkout([module] [revision] [date]) || die "Could not check out";
		
=head1 DESCRIPTION

This is a MacCVS interface for talking to MacCVS Pro client.
MacCVSSession is the class used to manipulate the session

=item new
	MacCVS->new( <cvs session file path>);
	
	Creates a new session. Returns undef on failure.

=item checkout( <module> [revision] [date] )

	cvs checkout command. Revision and date are optional
	returns 0 on failure
	
=cut

=head1 SEE ALSO

=over

=item MacCVS Home Page

http://www.maccvs.org/

=back 

=head1 AUTHORS

Aleks Totic atotic@netscape.com

=cut

__END__

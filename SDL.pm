package Imager::SDL;
use strict;
use vars qw($VERSION @ISA);
use Imager;
use SDL::Video;

BEGIN {
  $VERSION = "0.01";
  push @ISA, 'Imager';

  eval {
    require XSLoader;
    XSLoader::load('Imager::SDL', $VERSION);
  } or do {
    require DynaLoader;
    push @ISA, 'DynaLoader';
    bootstrap Imager::SDL $VERSION;
  };
}

sub new {
  my $class = shift;

  my %opts = (auto_update => 0, @_);

  $opts{surface} 
    or return $class->_set_error("No surface supplied to $class->new");

  $opts{surface}->isa("SDL::Surface")
    or return $class->_set_error("surface not a SDL::Surface");
  
  my $raw = i_img_sdl_new($opts{surface}, $opts{auto_update});
  unless ($raw) {
    $Imager::ERRSTR = $class->_error_as_msg;
    return;
  }
  
  return bless { 
                IMG => $raw, 
                SURFACE => $opts{surface},
               }, $class;
}

sub auto_lock {
  my ($self, $auto_lock) = @_;

  i_sdl_auto_lock($self->{IMG}, $auto_lock);
}

sub lock {
  SDL::Video::lock_surface($_[0]->{SURFACE});
}

sub unlock {
  SDL::Video::unlock_surface($_[0]->{SURFACE});
}

sub update {
  i_sdl_update($_[0]{IMG});
  #$_[0]->{SURFACE}->update;
}

1;

__END__

=head1 NAME

Imager::SDL - Imager image interface to SDL::Surface objects.

=head1 SYNOPSIS

  use SDL;
  use SDL::App;
  use Imager::SDL;

  my $app = SDL::App->new(...)
    or die SDL::GetError();
  my $img = Imager::SDL->new(surface => $app)
    or die Imager->errstr;

  $img->lock;
  # draw stuff
  $img->box(filled=>1, color => $color, ...);
  ...
  $img->unlock;
  $img->update;

=head1 DESCRIPTION

Imager::SDL allows you to use Imager's drawing methods to draw on a
SDL surface.

Nearly all methods can be used, the exception being those methods that
replace the low level image object inside the Imager object.  These
methods include:

=over

=item *

read()

=item *

img_set()

=back

=head1 METHODS

=over

=item new

Creates a new Imager::SDL object.  Parameters:

=over

=item *

surface - an SDL::Surface (or SDL::App, which isa SDL::Surface) to be
drawn on by the Imager object.  Required.

=item *

auto_update - if true then every low level write on the surface will
result in an update to that area of the surface.  It's faster to use
the update() method after a batch of updates to the surface.  Default:
0.

=back

=item lock

Locks the surface so Imager can render or read from the surface.
Equivalent to calling lock() directly on the surface.

=item unlock

Unlocks the surface.

=item auto_lock

Called as:

  $img->auto_lock($auto_lock);

If $auto_lock is true then Imager::SDL will lock the surface itself
anytime it needs to read or write the surface.

This is not recommended and may be removed in a future release.

=item update

Calls SDL_UpdateRect() for the rectangle of the surface that has been
modified through Imager calls since the last update() call.

=back

=head1 SDL INTERACTIONS

=head2 SDL::App->new

As of 2.1.3 SDL::App->new will return true even if creating the
surface fails.  Imager::SDL->new will detect this and return false.

=head2 SDL_VIDEORESIZE

If you handle SDL_VIDEORESIZE events by calling SDL::App's resize
method you should create a new Imager::SDL object.

=head2 SDL::App->loop

As of SDL_perl 2.1.3 SDL::App->loop will call its sync() method each
time around the event loop, for software surfaces this can cause some
performance issues, this is especially noticable with interactive
graphics.

=head1 AUTHOR

Tony Cook <tony@imager.perl.org>

=head1 SEE ALSO

Imager, SDL, SDL::App, SDL::Surface

=cut

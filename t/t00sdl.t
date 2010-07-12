
#!perl -w
use strict;
use SDL;
use SDL::Video;
use SDL::Surface;
use Test::More tests => 6;

BEGIN { use_ok 'Imager::SDL'; }

SDL::init(SDL_INIT_VIDEO);

# warns if -name is undef in older SDL::Surface
my $display = SDL::Video::set_video_mode(640, 480, 32, SDL_SWSURFACE);
my $surface = SDL::Surface->new(SDL_SWSURFACE, 100, 100);
ok($surface, "make SDL surface");
my $im = Imager::SDL->new(surface => $surface);
ok($im, "make imager proxy")
  or print "# ", Imager->errstr, "\n";

# make sure we saved the surface
is($im->{SURFACE}, $surface, "saved surface object");

is($im->getwidth, 100, "check width transferred");

# fill it
$im->lock;
$im->box(filled=>1, color=>'FF0000');
$im->unlock;
#$im->update;
#$surface->update(SDL::Rect->new(-height=>0, -width=>0));
$im->update;

# make sure we set them as expected
my $sdlc = $surface->get_pixel(0);
is($sdlc & 0xffffff, 0x0000ff, "check color");

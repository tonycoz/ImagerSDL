#!perl -w
use strict;
use SDL;
use SDL::Surface;
use Test::More tests => 7;

BEGIN { use_ok 'Imager::SDL'; }

# warns if -name is undef in older SDL::Surface
my $surface = SDL::Surface->new(-name => '', -width=>100, -height=>100, -depth=>24);
ok($surface, "make SDL surface");
my $im = Imager::SDL->new(surface => $surface);
ok($im, "make imager proxy");

# make sure we saved the surface
is($im->{SURFACE}, $surface, "saved surface object");

# fill it
$im->lock;
$im->box(filled=>1, color=>'FF0000');
$im->unlock;
#$im->update;
#$surface->update(SDL::Rect->new(-height=>0, -width=>0));
$surface->update;

# make sure we set them as expected
my $sdlc = $surface->pixel(0, 0);

is($sdlc->r, 255, "check red");
is($sdlc->g, 0, "check green");
is($sdlc->b, 0, "check blue");

#!perl -w
use strict;
use Imager;
use SDL;
use SDL::App;
use SDL::Event;
use SDL::Surface;
use Imager::SDL;
use Imager::Filter::Mandelbrot;

use constant MANDEL_SELECTION => 24; # SDL_USEREVENT

# SDL::App->new will return true even if it couldn't create a surface
my $app = SDL::App->new(-title => "Test",
                        -width => 640,
                        -height => 480,
                        -depth => 32,
                        -resizeable => 1,
                        -flags => SDL_HWACCEL)
  or die "Cannot make app: ", SDL::GetError(), "\n";

# which Imager::SDL handles by failing
my $im = Imager::SDL->new(surface => $app, auto_update => 0)
  or die "Cannot make Imager proxy: ", Imager->errstr, " (", SDL::GetError(), ")\n";

my $mouse_down; # non-zero if mouse button pressed
my @start = ( -2.5, -1.5, 1.5, 1.5 ); # initial edges of rendered region
my ($minx, $miny, $maxx, $maxy) = @start;
my ($drag_x, $drag_y); # start of drag
my @history; # history of rendered regions
my $old_select; # last rendered selection box, used to restore display

# whether or not to show previews before the final render
# press p to change
my $previews;

# type of selection to display
# press s to change
my $sel_type = 0;

# non-zero if we've posted a selection event but haven't seen it
# used to prevent sending an extra
my $active_selection_event;

# last place we saw the mouse with the button down, used in the selection
# event handler to define the region drawn
my $last_drag_x;
my $last_drag_y;

# color of $sel_type == 1 selection box
my $select_col = Imager::Color->new('FF0000');

++$|;
print "Status: Idle   p: preview mode | s: select mode | BkSp: unzoom | q: quit\r";

my $backbuffer;
render($im);

my %actions =
  (
   SDL_KEYDOWN() => \&event_keydown,
   SDL_MOUSEBUTTONDOWN() => \&event_mousebuttondown,
   SDL_MOUSEMOTION() => \&event_mousemotion,
   SDL_MOUSEBUTTONUP() => \&event_mousebuttonup,
   SDL_VIDEORESIZE() => \&event_videoresize,
   MANDEL_SELECTION() => \&event_selection,

   SDL_QUIT() => sub { print "\n"; exit },
  );

$app->loop(\%actions);

# SDL::App's loop() method calls sync() for every event that's processed
# so don't use it if you're using Imager::SDL's update method.
sub loop {
  my ($self,$href) = @_;

  my $event = new SDL::Event;
  while ( $event->wait() ) {
    if ( ref($$href{$event->type()}) eq "CODE" ) {
      &{$$href{$event->type()}}($event);
    }
  }
}

sub event_keydown {
  my $event = shift;
  my $key = $event->key_sym;

  if ($key == SDLK_q) {
    print "\n"; 
    exit;
  }
  elsif ($key == SDLK_p) {
    $previews = !$previews;
  }
  elsif ($key == SDLK_s) {
    $sel_type = 1 - $sel_type;
    # switching can leave rubbish, since line mode only restores what
    # it needs to
    if ($old_select) {
      $im->paste(img => $backbuffer, 
                 left => $old_select->[0], top=>$old_select->[1],
                 src_coords => $old_select);
      undef $old_select;
    }
  }
  elsif ($key == SDLK_BACKSPACE || $key == SDLK_DELETE) {
    if (@history) {
      ($minx, $miny, $maxx, $maxy) = @{pop @history};
      render();
    }
  }
}

# start a mouse drag
sub event_mousebuttondown {
  my $event = shift;

  $mouse_down = 1;
  $app->grab_input(SDL_GRAB_ON);
  $drag_x = $event->button_x;
  $drag_y = $event->button_y;
}

# catch movements while the mouse is down, and occasionally display
# a selection box (see event_selection)
sub event_mousemotion {
  my $event = shift;

  if ($mouse_down) {
    $last_drag_x = $event->button_x;
    $last_drag_y = $event->button_y;
    if (!$active_selection_event) {
      my $sel_event = SDL::Event->new;
      $sel_event->type(MANDEL_SELECTION);
      #$sel_event->push;
      SDL::Events::push_event($sel_event);
      ++$active_selection_event;
    }
  }
}

# Drawing of the selection is left until here to prevent a large
# of mouse events building up.
# 
# By pushing an event we don't attempt to update the display until the
# current backlog of mouse events have been processed.
sub event_selection {
  my $event = shift;

  $active_selection_event = 0;
  if ($mouse_down) {
    if ($old_select) {
      if ($sel_type == 0) {
        # restore from the back buffer
        $im->paste(img => $backbuffer, 
                   left => $old_select->[0], top=>$old_select->[1],
                   src_coords => $old_select);
      }
      else {
        # just the edges
        my @old = @$old_select;
        $im->paste(img => $backbuffer,
                   left => $old[0], top => $old[1],
                   src_coords => [ @old[0,1,2], $old[1]+1 ]);
        $im->paste(img => $backbuffer,
                   left => $old[0], top => $old[1]+1,
                   src_coords => [ $old[0], $old[1]+1, $old[0]+1, $old[3]-1 ]);
        $im->paste(img => $backbuffer,
                   left => $old[2]-1, top => $old[1]+1,
                   src_coords => [ $old[2]-1, $old[1]+1, $old[2], $old[3]-1 ]);
        $im->paste(img => $backbuffer,
                   left => $old[0], top => $old[3]-1,
                   src_coords => [ $old[0], $old[3]-1, @old[2,3] ]);
      }
    }
    my ($sel_left, $sel_right) = sort { $a <=> $b } ($drag_x, $last_drag_x);
    my ($sel_top, $sel_bottom) = sort { $a <=> $b } ($drag_y, $last_drag_y);
    $old_select = [ $sel_left, $sel_top, $sel_right+1, $sel_bottom+1 ];
    
    # mark the selection
    $im->lock;
    if ($sel_type == 0) {
      # invert the contents of the box
      my $mask = $im->masked(left => $sel_left, top => $sel_top,
                             right => $sel_right+1, bottom => $sel_bottom+1);
      $mask->filter(type=>'hardinvert');
    }
    else {
      # just draw a box around it
      $im->box(xmin=>$sel_left, ymin => $sel_top, 
               xmax=>$sel_right, ymax=>$sel_bottom, color=>$select_col);
    }
    $im->unlock;
    $im->update;
  }
}

sub event_mousebuttonup {
  my $event = shift;

  if ($mouse_down) {
    $app->grab_input(SDL_GRAB_OFF);
    $mouse_down = 0;
    my $last_x = $event->button_x;
    my $last_y = $event->button_y;
    if ($last_x != $drag_x && $last_y != $drag_y) {
      my ($min_scr_x, $max_scr_x) = sort { $a <=> $b } ($drag_x, $last_x);
      my ($min_scr_y, $max_scr_y) = sort { $a <=> $b } ($drag_y, $last_y);
      my $scr_center_x = ($min_scr_x + $max_scr_x) / 2;
      my $scr_center_y = ($min_scr_y + $max_scr_y) / 2;

      # remember for the "go back" operation
      push @history, [ $minx, $miny, $maxx, $maxy ];

      # try to keep the scaled size proportional
      # scale per pixel in the src
      my $src_scale_x = ($maxx - $minx) / $im->getwidth;
      my $src_scale_y = ($maxy - $miny) / $im->getheight;

      my $center_x = $minx + $src_scale_x * $scr_center_x;
      my $center_y = $miny + $src_scale_y * $scr_center_y;

      # scale per pixel in final
      my $scale_x = $src_scale_x * ($max_scr_x - $min_scr_x) / $im->getwidth;
      my $scale_y = $src_scale_y * ($max_scr_y - $min_scr_y) / $im->getheight;
      my $scale = $scale_x > $scale_y ? $scale_y : $scale_x;

      my $new_minx = $center_x + $scale * - $im->getwidth / 2;
      my $new_maxx = $center_x + $scale * $im->getwidth / 2;
      my $new_miny = $center_y + $scale * - $im->getheight / 2;
      my $new_maxy = $center_y + $scale * $im->getheight / 2;

      ($minx, $miny, $maxx, $maxy) = 
        ($new_minx, $new_miny, $new_maxx, $new_maxy);
      undef $old_select;    
      render();
    }
  }
}

# user resized the window, resize the surface to match
sub event_videoresize {
  my $event = shift;
  my ($width, $height) = ($event->resize_w, $event->resize_h);
  $app->resize($width, $height);
  $im = Imager::SDL->new(surface => $app)
    or die "Resize error: ", Imager->errstr, "(", SDL::GetError(), ")\n";
  render();
}

sub render {
  print "Status: Render\r";
  if ($previews) {
    # 2 passes, one in low res
    my $low = Imager->new(xsize => $im->getwidth / 4, ysize => $im->getheight / 4);
    $low->filter(type=>'mandelbrot', minx => $minx, miny => $miny, maxx => $maxx, maxy => $maxy);
    my $scale = $low->scale(scalefactor => 4);
    $im->lock;
    $im->paste(src=>$scale);
    $im->unlock;
    $im->update;
  }

  # other in detail
  $im->lock;
  $im->filter(type=>'mandelbrot', minx => $minx, miny => $miny, maxx => $maxx, maxy => $maxy);
  # backbuffer is used to restore the image after drawing the select box
  $backbuffer = $im->copy;
  $im->unlock;
  $im->update;
  print "Status: Idle  \r";
}

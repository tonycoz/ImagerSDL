use ExtUtils::MakeMaker;
use Imager::ExtUtils;

my $sdl_cflags = `sdl-config --cflags`
  or die "No sdl-config found\n";
chomp $sdl_cflags;
my $sdl_libs   = `sdl-config --libs`;
chomp $sdl_libs;

my %opts = 
  (
   NAME => 'Imager::SDL',
   VERSION_FROM => 'SDL.pm',
   OBJECT => 'SDL.o imsdl.o',
   INC => $sdl_cflags . ' ' . Imager::ExtUtils->includes,
   LIBS => $sdl_libs,
   TYPEMAPS => [ Imager::ExtUtils->typemap ],
   PREREQ_PM =>
   {
    Imager => 0.47,
    SDL => '1.20',
   },
  );
if ($ExtUtils::MakeMaker::VERSION > 6.06) {
  $opts{AUTHOR} = 'Tony Cook <tony@imager.perl.org>';
  $opts{ABSTRACT} = 'Imager interface to a SDL surface';
}

WriteMakefile(%opts);

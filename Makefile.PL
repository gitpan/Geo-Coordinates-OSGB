use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
  NAME		 => 'Geo::Coordinates::OSGB',
  VERSION_FROM   => 'lib/Geo/Coordinates/OSGB.pm',
  ABSTRACT_FROM  => 'lib/Geo/Coordinates/OSGB.pm',
  # force tar to set permissions properly for new indexer
  dist		 => {TARFLAGS => '--create --verbose --mode=0755 --file '},
);




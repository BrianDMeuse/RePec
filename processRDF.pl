#!/usr/bin/perl -w
   
use strict;
use ReDIF::Parser qw( &redif_open_file 
                      &redif_parse_string
                      &redif_get_next_template 
                      &redif_get_next_template_good_or_bad
                      &redif_open_dir 
                      &redif_open_dir_recursive
                    );
use FileHandle;
use XML::Simple;
use XML::LibXSLT;
use XML::LibXML;
use Net::FTP;
use DB_File;
use Time::localtime;
use Getopt::Long;

# Options
my %opts = (); 
my %receivedRDF;
my $updatedFile = 0;
my @files;

main();

#-----------------------------------------------------------------------------
sub main {
    
    my $fullreload = shift @ARGV
        if (@ARGV);
	
    # Initialize settings
    initSettings();
   my $tm = localtime;
   my $timestamp = sprintf("%04d%02d%02d", $tm->year+1900, ($tm->mon)+1, $tm->mday);    
    
    # keep tally of date files last updated
    my $receivedRDF = $opts{db};

    tie %receivedRDF, "DB_File", $receivedRDF;
    
    if ($fullreload) { # Just process files
	@files = split(/,/,$opts{files});
	$updatedFile = 1;
	newFiles($timestamp);	
    } else {
	newFiles($timestamp);
    }
    
    if ($updatedFile == 1) {
	
	print "UPDATED data files - generating new XML for ingest.\n";
	
	mkdir ($timestamp.'_xml');

	my $outputFHStream = new FileHandle;
	my $outputFHNoStream = new FileHandle;	
	
	my $outputXMLStream = $timestamp.'_xml/' . $timestamp.'_repecPDF.xml';
	$outputFHStream->open("> $outputXMLStream");
	
	my $outputXMLNoStream = $timestamp.'_xml/' . $timestamp.'_repecNOPDF.xml';
	$outputFHNoStream->open("> $outputXMLNoStream");
	
	# TO DO Write doc using XML::LibXML::Document	
    	#my $doc = XML::LibXML::Document->createDocument('1.0','UTF-8');
	#my $root = $doc->createElement('records');
	#$root->setAttribute('xmlns:xsi'=> 'http://www.w3.org/2001/XMLSchema-instance');
	#$root->setAttribute('xmlns:dc'=> 'http://purl.org/dc/elements/1.1/');
	#$root->setAttribute('xmlns:dcterms'=> 'http://purl.org/dc/terms/');
	
	my $header = '<?xml version="1.0" encoding="UTF-8"?><records xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/">';
	
	print $outputFHStream $header;
	print $outputFHNoStream $header;
	
	my $records; 
	foreach my $file (@files) {

	    $file = $timestamp . '_rdf\\' . $file;
	    
	    redif_open_file($file);
	    my $template;
	    
	    while ( $template = redif_get_next_template( ) ) {
               
		my $xml = XMLout($template);
		
		# strip random junk from RDF file
		$xml =~ s/[\x03\x0b\x16\x1a\x0e]+//g;
				        
		my $parser = XML::LibXML->new();
		my $xslt = XML::LibXSLT->new();
        
		my $source = $parser->parse_string($xml);
	
		my $style_doc = $parser->parse_file('ReDIFtoDC.xslt'); 
		my $stylesheet = $xslt->parse_stylesheet($style_doc);
		my $results = $stylesheet->transform($source);
		my $record = $stylesheet->output_as_bytes($results);	

		if ($record =~ /dcterms:IsVersionOf/ ) {
		    print $outputFHNoStream $record;
		} else {
	 	    print $outputFHStream $record;
		}
	    }   
	}

	#$doc->setDocumentElement( $root );
	
	print $outputFHStream '</records>';
	print $outputFHNoStream '</records>';	
	
    }

    exit 1;

}
#-----------------------------------------------------------------------------
sub newFiles {
    
    my $timestamp = shift;
    my $ftp = Net::FTP->new($opts{ftp});

    print "\nprocessRDF STARTED $timestamp\n";
   
    @files = split(/,/,$opts{files});
   
    $ftp->login();
        
    $ftp->cwd($opts{fetchdir});
      
    if ($updatedFile == 0) {
    
	foreach my $file (@files) {
    
	    # Get last modification time for each file
	    my $mod = $ftp->mdtm($file);
	
	    if  (exists $receivedRDF{$file}) {
	        unless ($receivedRDF{$file} == $mod) {
		    $receivedRDF{$file} = $mod;
		    $updatedFile = 1;
		}		    
	    } else { # new file
	        $receivedRDF{$file} = $mod;
		$updatedFile = 1;
	    }
	}
   }
    
    if ($updatedFile == 1) {
	mkdir ($timestamp.'_rdf');
	foreach my $file (@files) { #Get all files - full reload
	    $ftp->get($file,$timestamp.'_rdf/'.$file);
	}
    } else {
	print "No updated data files to process\n";
	exit  1;
    }
}
#-----------------------------------------------------------------------------
sub initSettings {
    
   GetOptions ("config=s" => \$opts{config},
                              "db=s" => \$opts{db},
                              "ftp=s" => \$opts{ftp},
                      "fetchdir=s" => \$opts{fetchdir},
	                    "files=s" => \$opts{files});
	
   $opts{config} = 'processRDF.config'
      if !($opts{config});								

   # read settings from config
   my $configFH = new FileHandle;
	
   $configFH->open($opts{config});

   while(not($configFH->eof)) {
      my $lineIn = $configFH->getline;
      chomp $lineIn;
      # skip comments
      unless ( $lineIn =~ /^#/ ) {
         $lineIn =~ s/\s//g;
	 $lineIn =~ /(.+)\=(.+)/;
	 my ($key, $value) = ($1, $2);	 
	 $opts{$key} = $value;		    
      }
   }
    
   $configFH->close();
}
#-----------------------------------------------------------------------------




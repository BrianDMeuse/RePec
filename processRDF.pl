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
use File::Fetch;
use XML::Simple;
use XML::LibXSLT;
use XML::LibXML;
use XML::XPath;      
use Net::FTP;
use Time::localtime;
use Getopt::Long;

# Options
my %opts = (); 
my @files;

main();

#-----------------------------------------------------------------------------
sub main {
	
    # Initialize settings
    initSettings();
   my $tm = localtime;
   my $timestamp = sprintf("%04d%02d%02d", $tm->year+1900, ($tm->mon)+1, $tm->mday);    
    
    @files = split(/,/,$opts{files});
    newFiles($timestamp);
    
    my $xmlDir =    $timestamp.'_xml';
    
    mkdir ($xmlDir);
	
    my $records; 

    foreach my $file (@files) {

	$file = $timestamp . '_rdf\\' . $file;
	    
        redif_open_file($file);
        my $template;
	    
        while ( $template = redif_get_next_template( ) ) {
               
	    my $xml = XMLout($template);
		
	    # strip random junk from RDF file
	    $xml =~ s/[\x03\x0b\x16\x1a\x0e]+//g;
			
	    # RDF To DC	        
	    my $rdfparser = XML::LibXML->new();
	    my $rdfxslt = XML::LibXSLT->new();
        
	    my $rdfsource = $rdfparser->parse_string($xml);
	
	    my $rdfstyle_doc = $rdfparser->parse_file($opts{rdfxsl}); 
	    my $rdfstylesheet = $rdfxslt->parse_stylesheet($rdfstyle_doc);
	    my $rdfresults = $rdfstylesheet->transform($rdfsource);
	    my $rdfrecord = $rdfstylesheet->output_as_bytes($rdfresults);	
	    
	    my $pdfFile = XML::XPath->new( xml => $rdfrecord );
	    my $pdfUrl = $pdfFile->findvalue('/record/dcterms:URI');
	    
	    if ($pdfUrl) {
		my $ff = File::Fetch->new(uri => $pdfUrl);
		my $where = $ff->fetch( to => $xmlDir );
	    }
	    
	    # DC To MODS
	    my $modsparser = XML::LibXML->new();
	    my $modsxslt = XML::LibXSLT->new();
        
	    my $modssource = $modsparser->parse_string($rdfrecord);
	
	    my $modsstyle_doc = $modsparser->parse_file($opts{modsxsl}); 
	    my $modsstylesheet = $modsxslt->parse_stylesheet($modsstyle_doc);
	    my $modsresults = $modsstylesheet->transform($modssource);
	    my $modsrecord = $modsstylesheet->output_as_bytes($modsresults);	    
	    
	    
	    my $xpFile = XML::XPath->new( xml => $modsrecord );
	    my $filename = 'wp' . $xpFile->findvalue('/mods:mods/mods:relatedItem/mods:titleInfo/mods:partNumber') . '.xml';
	        
	    my $modsFH = new FileHandle;
	    
	    my $outputXMLStream = $timestamp.'_xml/' . $filename;
	    
	    $modsFH->open("> $outputXMLStream");
	    
	    print $modsFH $modsrecord;
	}	
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

    mkdir ($timestamp.'_rdf');
    foreach my $file (@files)  {  
	    $ftp->get($file,$timestamp.'_rdf/'.$file);
    }

}
#-----------------------------------------------------------------------------
sub initSettings {
    
   GetOptions ("config=s" => \$opts{config},
                              "ftp=s" => \$opts{ftp},
                      "fetchdir=s" => \$opts{fetchdir},
	                    "files=s" => \$opts{files},
                          "rdfxsl=s" => \$opts{rdfxsl},
			"modsxsl=s" => \$opts{modsxsl});
	
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




# Make sure project.xml is in current working directory

#my $projectName = 'ProjectAsCode';

#!ec-perl
# toProjectAsCode.pl
# Converts a Commander project into ProjectAsCode-ready set of files:
# - Steps:  project/<procedureName>-<stepName><.extension>
# - project/manifest.pl
# - project/project.xml.in

use ElectricCommander;
use strict;
use warnings;
use XML::LibXML;

$| = 1;

# TODO: remove old one if it exists
mkdir "project";

my $manifest = ""; # manifest.pl file content
my $ec = new ElectricCommander();

#Create the export file
# $ec->export('project.xml',{
	# path => "/projects/$projectName",
	# excludeJobs => 'true',
	# relocatable => 'true',
	# withNotifiers => 'true'
	# });

# Load export file
my $filename = "project.xml";
my $parser = XML::LibXML->new();
my $projectXml = $parser->parse_file($filename);

# Make sure project/propertySheet exists
my $projectNode=$projectXml->findnodes('/exportedData/project');
if (!$projectXml->findnodes('/exportedData/project/propertySheet')) {
	my $propertySheet = $projectXml->ownerDocument->createElement('propertySheet');
	$projectNode->[0]->appendChild($propertySheet);
}

# Add plugin properties
my $projectPropertySheet=$projectXml->findnodes('/exportedData/project/propertySheet');
# Add ec_setup -> PLACEHOLDER property
my $ec_setup = $projectXml->ownerDocument->createElement('property');
$ec_setup->appendTextChild('propertyName',"ec_setup");
$ec_setup->appendTextChild('value',"PLACEHOLDER");
$projectPropertySheet->[0]->appendChild($ec_setup);
# Add project_version -> @PLUGIN_VERSION@ property
my $project_version = $projectXml->ownerDocument->createElement('property');
$project_version->appendTextChild('propertyName',"project_version");
$project_version->appendTextChild('value','@PLUGIN_VERSION@');
$projectPropertySheet->[0]->appendChild($project_version);

# Replace some plugin values
#exportPath: /projects/exportPath -> /projects/@PLUGIN_KEY@
my $exportPathNode=($projectXml->findnodes('/exportedData/exportPath'))[0];
$exportPathNode->removeChildNodes;  # Remove the current value
$exportPathNode->appendText('/projects/@PLUGIN_KEY@'); # Insert new value
#projectName -> @PLUGIN_KEY@
my $projectNameNode=($projectXml->findnodes('/exportedData/project/projectName'))[0];
$projectNameNode->removeChildNodes;  # Remove the current value
$projectNameNode->appendText('@PLUGIN_KEY@'); # Insert new value

$manifest .= qq(\@files = \(
	['//project/propertySheet/property[propertyName="ec_setup"]/value', 'ec_setup.pl'],\n);

foreach my $procedure ($projectXml->findnodes('/exportedData/project/procedure')) {
	my $procedureName = $procedure->find("procedureName")->string_value;
	#print "Procedure: $procedureName\n";
	foreach my $step ($procedure->findnodes('step')) {
		my $stepName = $step->find("stepName")->string_value;
		my $shell = $step->find("shell")->string_value;
		my $command = $step->find("command")->string_value;
		#print "	Step: $stepName\n";
		# Replace command -> PLACEHOLDER (not for subproject steps)
		my $stepNode=($step->findnodes('command'))[0];
		if ($stepNode) {
			$stepNode->removeChildNodes;  # Remove the current value
			$stepNode->appendText('PLACEHOLDER'); # Insert new value
		}
		#
		my $ext=".sh"; # No way to detect whether sh or cmd
		$ext = ".pl" if ($shell eq 'ec-perl' || $shell eq 'perl');
		my $commandFile = "$procedureName-$stepName${ext}";
		open (COMMAND, ">project/$commandFile") or die "$!\n";
		print COMMAND $command, "\n";
		close COMMAND;
		$manifest .= qq(	['//project/procedure[procedureName="$procedureName"]/step[stepName="$stepName"]/command', '$procedureName-$stepName${ext}'],\n);
	} # step
} # procedure

$manifest .= qq(\););
open (MANIFEST, ">project/manifest.pl") or die "$!\n";
print MANIFEST $manifest, "\n";
close MANIFEST;

open (TEMPLATE, ">project/project.xml.in") or die "$!\n";
print TEMPLATE $projectXml->toString(1);
close TEMPLATE;
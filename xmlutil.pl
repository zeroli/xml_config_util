#!/usr/bin/env perl
#* vim:set ts=4 sw=4 nohlsearch number incsearch showmatch : *#
# package class(XmlUtil) to wrapper xml DOM node handling 
#
package XmlUtil;

use XML::LibXML;

require "tidyxml.pl";

sub Load {
	my $xmlf = shift;
	return undef unless (-f $xmlf);
	
	my $parser = XML::LibXML->new();
	my $doc = $parser->parse_file($xmlf);
	return undef unless (defined $doc);
	return $doc->documentElement;
}

sub Save {
	my $outxmlf = shift;
	my $outdoc = shift;
	return 0 unless (defined $outdoc);

	open OUTPUT, "> $outxmlf" or return 0;
	PrintNode($outdoc, OUTPUT);
	close OUTPUT;
	return 1;
}

sub GetNode {
	my ($pnode, $name, $index) = @_;
	
	return undef unless (defined $pnode && $name);
	$index = 0 unless (defined $index);

	my @keys = split(/\./, $name);
	my $node1 = $pnode;
	for (my $k = 0; $k < @keys-1; $k++) {
		$node1 = GetNode($node1, $keys[$k]);
		return undef unless (defined $node1);
	}

	my $lasttag = $keys[-1];
	my ($key, $idx) = $lasttag=~m/(.*)\[(\d+)\]$/;
	if (defined $key) {
		$lasttag = $key;
		$index = $idx;
	}
	
	my @nodes = $node1->getChildrenByTagName($lasttag);
	my $n = 0;
	foreach my $node (@nodes) {
		if ($node->nodeType == XML_ELEMENT_NODE)
		{
			return $node if ($n == $index);
			$n++;
		}
	}
	return undef;
}

sub SetNode {
	my ($pnode, $name, $index) = @_;
	
	return undef unless (defined $pnode && $name);
	$index = 0 unless (defined $index);

	my @keys = split(/\./, $name);
	my $node1 = $pnode;
	for (my $k = 0; $k < @keys-1; $k++) {
		$node1 = GetNode($node1, $keys[$k]);
		return undef unless (defined $node1);
	}

	my $lasttag = $keys[-1];
	my ($key, $idx) = $lasttag=~m/(.*)\[(\d+)\]$/;
	if (defined $key) {
		$lasttag = $key;
		$index = $idx;
	}
	
	my @nodes = $node1->getChildrenByTagName($lasttag);
	
	if (scalar(@nodes) == 0) {
		return $node1->appendChild(CreateNode($lasttag, ""));
	} else {	# locate node
		my $n = 0;
		foreach my $node (@nodes) {
			if ($node->nodeType() == XML_ELEMENT_NODE) {
				return $node if ($n == $index);
				$n++;
			}
		}
		my $newnode = CreateNode($lasttag, "");
		my $lastindex = scalar(@nodes) - 1;
		InsertNodeAfter($node1, $newnode, $lasttag."[$lastindex]");
		return $newnode;
	}
}

# Please Note: Below 2 functions will move new node from original xml tree
# better duplicate one copy using Clone function, before calling
sub InsertNodeAfter {
	my ($pnode, $newnode, $name) = @_;
	
	return 0 unless (defined $newnode);
	
	my $refnode = GetNode($pnode, $name);
	return 0 unless (defined $refnode);
	
	my $node1 = $refnode->parentNode;
	return 0 unless (defined $node1);
	
	$node1->insertAfter($newnode, $refnode);
	return 1;
}

sub InsertNodeBefore {
	my ($pnode, $newnode, $name) = @_;
	
	return 0 unless (defined $newnode);
	
	my $refnode = GetNode($pnode, $name);
	return 0 unless (defined $refnode);

	my $node1 = $refnode->parentNode;
	return 0 unless (defined $node1);
	
	$node1->insertBefore($newnode, $refnode);
	return 1;
}

sub DeleteNode {
	my ($pnode, $name, $index) = @_;
	return 0 unless (defined $pnode);

	$name = "text" unless ($name);

	my @keys = split(/\./, $name);
	my $node1 = $pnode;
	for (my $k = 0; $k < @keys-1; $k++) {
		$node1 = GetNode($node1, $keys[$k]);
		return 0 unless (defined $node1);
	}

	my $lasttag = $keys[-1];
	my ($key, $idx) = $lasttag=~m/(.*)\[(\d+)\]$/;
	if (defined $key) {
		$lasttag = $key;
		$index = $idx;
	}
	
	my @nodes = $node1->getChildrenByTagName($lasttag);
	return 0 if (scalar(@nodes) == 0);
	
	unless (defined $index) {
		foreach (@nodes) {	
			$node1->removeChild($_);
		}
	} else {
		my $node = $nodes[$index];
		$node1->removeChild($node) if (defined $node);
	}
	return 1;
}

sub AddConfigData {
	my ($node1, $node2) = @_;
	return unless (defined $node1 && defined $node2);
	foreach my $node ($node2->childNodes) {
		$node1->addChild($node->cloneNode(1));
	}
}

sub GetConfigData {
	my ($pnode, $name, $defval, $index) = @_;

	my $data = $defval;
	
	return $data unless (defined $pnode);
	
	$name = "text" unless ($name);

	my @keys = split(/\./, $name);
	my $node1 = $pnode;
	for (my $k = 0; $k < @keys-1; $k++) {
		$node1 = GetNode($node1, $keys[$k]);
		return $data unless (defined $node1);
	}

	my $lasttag = $keys[-1];
	my ($key, $idx) = $lasttag=~m/(.*)\[(\d+)\]$/;
	if (defined $key) {
		$lasttag = $key;
		$index = $idx;
	}

	my @nodes = $node1->getChildrenByTagName($lasttag);
	return $data if (scalar(@nodes) == 0);
	
	my $n = 0;
	foreach my $node (@nodes) {
		if ($node->nodeType == XML_ELEMENT_NODE ||
			$node->nodeType == XML_TEXT_NODE)
		{
			if ($n == $index) {
				if ($node->hasChildNodes()) { $data = $node->firstChild->nodeValue; }
				else { $data = $node->nodeValue; }
				last;
			}
			$n++;
		}
	}
			
	$data =~ s/^[\n|\s]+//;
	$data =~ s/[\n|\s]+$//;
	return $data;
}

sub SetConfigData {
	my ($pnode, $name, $data, $index) = @_;

	return 0 unless (defined $pnode);
	$name = "text" unless ($name);

	my @keys = split(/\./, $name);
	my $node1 = $pnode;
	for (my $k = 0; $k < @keys-1; $k++) {
		$node1 = GetNode($node1, $keys[$k]);
		return 0 unless (defined $node1);
	}

	my $lasttag = $keys[-1];
	my ($key, $idx) = $lasttag=~m/(.*)\[(\d+)\]$/;
	if (defined $key) {
		$lasttag = $key;
		$index = $idx;
	}
	
	my @nodes = $node1->getChildrenByTagName($lasttag);

	if (scalar(@nodes) > 0) {
		$index = 0 unless (defined $index);
		my $oldnode = $nodes[$index];
		SetNodeData($oldnode, $data) if (defined $oldnode);
	}
	else
	{
		if ($lasttag eq "text") {
			$node1->addChild(XML::LibXML::Text->new($data));
		} else {
			$node1->addChild(CreateNode($lasttag, $data));
		}
	}
	return 1;
}

sub GetConfigKeys {
	my $pnode = shift;
	my @keys;
	my %seen = ();
	return unless (defined $pnode && $pnode->hasChildNodes);
	
	foreach ($pnode->childNodes) {
		next if ($_->nodeType == XML_TEXT_NODE && $_->nodeValue =~ m/^\s*$/i);
		unless ($seen{$_->nodeName}) {
			push @keys, $_->nodeName;
			$seen{$_->nodeName} = 1;
		}
	}
	return @keys;
}

sub Clone {
	my $node = shift;
	return $node->cloneNode(1);
}

sub Node2Xml {
	my $node = shift;
	unless (defined $node) {
		return "";
	}
	return MyXML::tidy_xml($node->toString(1), {indentstring => "  ", arrayref => 1});
}

sub Xml2Node {
	my $xml = shift;
	my $parser = XML::LibXML->new();
	my $doc = $parser->parse_string($xml);
	unless (defined $doc) {
		return undef;
	}
	return $doc->documentElement;
}

sub PrintNode {
	my ($node, $output) = @_;
	unless (defined $node) {
		print "WARNING: Xml Node is undefined !\n";
		return;
	}
	unless (defined $output) {
		$output = STDOUT;
	}	
	my $outstr = Node2Xml($node);
	
	print $output $outstr;
	print $output "\n";
}

sub CreateNode {
	my ($name, $data) = @_;
	my $onenode = XML::LibXML::Element->new($name);
	if (defined $data) {
		my $textnode = XML::LibXML::Text->new($data);
		$onenode->appendChild($textnode);	
	}
	return $onenode;
}

sub SetNodeData {
	my ($node, $data) = @_;
	return unless (defined $node);
	
	my $name = $node->nodeName;
	my $newnode;
	if ($node->nodeType() == XML_TEXT_NODE) {
		$newnode = XML::LibXML::Text->new($data);	
	} else {
		$newnode = CreateNode($name, $data);
	}
	$node->replaceNode($newnode);
}

sub GetNumOfNodes {
	my ($pnode, $name) = @_;
	
	return 0 unless (defined $pnode && $name);

	my @keys = split(/\./, $name);
	my $node1 = $pnode;
	for (my $k = 0; $k < @keys-1; $k++) {
		$node1 = GetNode($node1, $keys[$k]);
		return undef unless (defined $node1);
	}

	my $lasttag = $keys[-1];
	my ($key, $idx) = $lasttag=~m/(.*)\[(\d+)\]$/;
	if (defined $key) {
		$lasttag = $key;
		$index = $idx;
	}
	
	my @nodes = $node1->getChildrenByTagName($lasttag);
	return scalar(@nodes);
}

sub IsEmptyNode {
	my $pnode = shift;
	if ($pnode->nodeType() == XML_TEXT_NODE) {
		my $data = $pnode->nodeValue();
		$data =~ s/^[\n|\s]+//;
		$data =~ s/[\n|\s]+$//;
		return 1 if ($data eq "");
	}
	if ($pnode->nodeType() == XML_ELEMENT_NODE) {
		my @nodes = $pnode->childNodes();
		foreach (@nodes) {
			if ($_->nodeType() == XML_TEXT_NODE) {
				if (!IsEmptyNode($_)) { return 0; }
				else { next; }
			}
			if ($_->nodeType() != XML_TEXT_NODE) {
				return 0;
			}
		}
		return 1;
	}
	return 0;
}

1;


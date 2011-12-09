<?php
$fp = fsockopen("localhost", 4489, $errno, $errstr);
$command = $_POST['command'];

if (!$fp) {
    echo "$errstr ($errno)<br />\n";
} else {
    	$out = $command . "\n";
    	fwrite($fp, $out);
   	//$incoming = fgets($fp, 128)
    
    	fclose($fp);
}
header( 'Location: http://localhost/' ) ;
?>

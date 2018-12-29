<?php


if ($_GET["e"] && mt_rand (0,1000)<$_GET["e"]) {
	http_response_code(404);
}
elseif ($_GET["q"]) {
	echo $_GET["q"];
}
else {
	echo 'empty';
}
?>
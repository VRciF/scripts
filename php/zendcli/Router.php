<?php

require_once ('Zend/Controller/Router/Interface.php');
require_once ('Zend/Controller/Router/Abstract.php');

class Index_Router extends Zend_Controller_Router_Abstract implements Zend_Controller_Router_Interface {

    public function assemble($userParams, $name = null, $reset = false, $encode = true) {}

    public function route(Zend_Controller_Request_Abstract $dispatcher) {}

}

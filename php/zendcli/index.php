#!/usr/bin/php
<?php

// load config

$configpath = dirname(__FILE__).DIRECTORY_SEPARATOR."Config".DIRECTORY_SEPARATOR;
if(!isset($_SERVER['APPLICATION_CONFIG'])){
	$_SERVER['APPLICATION_CONFIG'] = 'Default';
}
$configfile = "$configpath{$_SERVER['APPLICATION_CONFIG']}.php";
if(!file_exists($configfile)){
	die(__FILE__.":".__LINE__." [ERROR] given application config hasn't been found [{$configfile}, {$_SERVER['APPLICATION_CONFIG']}]");
}

define('APPLICATION_CONFIG', $_SERVER['APPLICATION_CONFIG']);

$configclass = "Config_".APPLICATION_CONFIG;

require_once($configfile);
if(!class_exists($configclass)){
	die(__FILE__.":".__LINE__." [ERROR] config class not found in given classfile [{$configclass}, {$configfile}]");
}

$config = new $configclass();
$config->init();

// Define path to application directory
defined('APPLICATION_PATH') || define('APPLICATION_PATH', realpath(dirname(__FILE__)));

// Define application environment
defined('APPLICATION_ENV') || define('APPLICATION_ENV', (getenv('APPLICATION_ENV') ? getenv('APPLICATION_ENV') : 'development'));

$include_paths = array(get_include_path(),
                       APPLICATION_PATH,
                       implode(PATH_SEPARATOR, $config->getIncludePath())
                      );
set_include_path(implode(PATH_SEPARATOR, $include_paths));

/** Zend_Application */
require_once 'Zend/Loader/Autoloader.php';
$autoloader = Zend_Loader_Autoloader::getInstance();

$config->registerNamespace($autoloader);

require_once 'Zend/Application.php';
require_once 'Zend/Registry.php';
require_once 'Router.php';

Zend_Registry::set('cliconfig', $config);

// Create application, bootstrap, and run
$application = new Zend_Application(APPLICATION_ENV, $config->getApplicationIni());

$config->preBootstrap($application);
$application->bootstrap();
$config->postBootstrap($application);

$front = Zend_Controller_Front::getInstance();
$front->setParam('disableOutputBuffering', true);
$front->setParam('noViewRenderer', true);
$front->setRouter(new Index_Router());
$front->setResponse(new Zend_Controller_Response_Cli());
$front->throwExceptions(true);

$request = new Zend_Controller_Request_Simple($config->getIndexAction(), $config->getIndexController());
$front->setRequest($request);

$application->run();


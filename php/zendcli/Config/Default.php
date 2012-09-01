<?php

if(!defined('APPLICATION_ENV')){
    define('APPLICATION_ENV', 'development');
}
if(!defined('APPLICATION_PATH')){
    define('APPLICATION_PATH', realpath(dirname(__FILE__).DIRECTORY_SEPARATOR.'..'));
}

require_once 'Abstract.php';

class Config_Default extends Config_Abstract{
    public $APPLICATION_ENV = APPLICATION_ENV;

    public function init(){}

    public function getIncludePath(){
        $library_path = dirname(__FILE__).DIRECTORY_SEPARATOR.'..'.DIRECTORY_SEPARATOR.'library'.DIRECTORY_SEPARATOR;
        $zf = @$_SERVER['ZF_PATH'];
        if(is_null($zf)){
        	$zf = $this->autoDetectZendFramework();
        	if(!is_null($zf)){
                trigger_error("Using zend framework located at: '{$zf}'", E_USER_NOTICE);
        	}
        }

        if(is_null($zf)){
        	$message = "not zend framework given and found:";
        	$message .= " you can set the environment variable ZF_PATH as a path to have it loaded OR on linux run 'updatedb'\n";
        	$message .= "if you dont know what an environment variable is have a look at {http://en.wikipedia.org/wiki/Environment_variable}";
        	$message .= " for info on how to set one and read {http://www.php.net/manual/en/reserved.variables.environment.php} to get yourself into using it";
        	die(__FILE__.":".__LINE__." [ERROR] $message");
        }

        /* the include path is must have the APPLICATION_ENV defined as a key in the following array */
        $include_path = array();
        $include_path['development'] = array(
                   'Library'=>$library_path,
                   'Zend'=>$zf,
               );

        if(!isset($include_path[APPLICATION_ENV])){ die("Include Path not yet set for APPLICATION_ENV:".APPLICATION_ENV." in ".__FILE__); }
        return $include_path[APPLICATION_ENV];
    }
    /* auto detection will only work on linux with 'locate' command being able to find Zend/Version.php */
    protected function autoDetectZendFramework(){
    	$result = array();
    	@exec("locate -e --follow Zend/Version.php", $result);
    	$final = null;
    	$finalversion = '0.0.0';
    	foreach($result as $file){
    		$parts = explode(DIRECTORY_SEPARATOR, $file);
    		$version = $parts[count($parts)-3];

    		$vcompare = version_compare($version, $finalversion);
    		if(is_null($final) || $vcompare>=0){
    			$final = $file;
    			$finalversion = $version;
    		}
    	}

    	if(!is_null($final)){
    		$final = dirname(dirname($final));
    	}

    	return $final;
    }

    public function getApplicationIni(){
        return APPLICATION_PATH . DIRECTORY_SEPARATOR .'Config'.DIRECTORY_SEPARATOR.'application.ini';
    }

    public function registerNamespace(Zend_Loader_Autoloader $autoloader){
//        $autoloader->registerNamespace('ProjectName');
    }

    public function preBootstrap(Zend_Application $application){}
    public function postBootstrap(Zend_Application $application){}

    public function getIndexController(){
    	$controller = @$_SERVER["argv"][1];

    	if(strlen($controller)<=0){
    		$controller = 'Index';
    	}

    	return $controller;
    }
    public function getIndexAction(){
    	$action = @$_SERVER["argv"][2];
    	if(strlen($action)<=0){
    		$action = 'index';
    	}

    	return $action;
    }
}


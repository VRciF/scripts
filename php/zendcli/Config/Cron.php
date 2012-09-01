<?php

if(!defined('APPLICATION_ENV')){
    define('APPLICATION_ENV', 'development');
}
if(!defined('APPLICATION_PATH')){
    define('APPLICATION_PATH', realpath(dirname(__FILE__).DIRECTORY_SEPARATOR.'..'));
}

require_once 'Default.php';

class Config_Cron extends Config_Default{
    public function init(){}

    public function registerNamespace(Zend_Loader_Autoloader $autoloader){
        $autoloader->registerNamespace('Cron');
    }

    public function preBootStrap(Zend_Application $application){
    	Zend_Registry::set('crontab',dirname(__FILE__).'/crontab');
    }

    public function getIndexController(){
    	return "Cronjob";
    }
    public function getIndexAction(){
    	return 'index';
    }
}


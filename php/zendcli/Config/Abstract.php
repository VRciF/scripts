<?php

abstract class Config_Abstract{
    public abstract function init();

    public abstract function getIncludePath();
    /* after the call to getIncludePath() by index.php you can use Zend_Registry::get('cliconfig') in your application
     * to get the instance of config currently in use
     */

    public abstract function getApplicationIni();

    public abstract function registerNamespace(Zend_Loader_Autoloader $autoloader);

    public abstract function preBootstrap(Zend_Application $application);
    public abstract function postBootstrap(Zend_Application $application);

    public abstract function getIndexController();
    public abstract function getIndexAction();
}

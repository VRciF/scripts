<?php

class Bootstrap extends Zend_Application_Bootstrap_Bootstrap
{

    public function _initConfig(){
        $config = new Zend_Config($this->getOptions());
        Zend_Registry::set('application_config', $config);
    }

}

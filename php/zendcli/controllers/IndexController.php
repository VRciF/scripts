<?php

class IndexController extends Zend_Controller_Action
{

    public function init(){}

    public function preDispatch(){}

    public function indexAction(){
    	var_dump("indexAction called in IndexController");
    }

    public function postDispatch(){}

}

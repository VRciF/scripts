<?php

abstract class Cron_Job_Abstract{
    protected $name    = "Abstract";

    protected $hasrun = false;

    public abstract function run();

    public function hasRun(){
        return $this->hasrun;
    }
    public function setHasRun($bool){
        $this->hasrun = $bool;
        return $this;
    }

    public function getJobName(){
        return $this->name;
    }

}


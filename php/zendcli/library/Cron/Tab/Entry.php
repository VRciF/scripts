<?php

require_once('Zend/Date.php');
require_once('Zend/Locale/Format.php');

require_once('Cron/Tab/ExecTime.php');
require_once('Cron/Job.php');

class Cron_Tab_Entry{
    protected $job      = null;
    protected $exectime = null;

    public function __construct(Cron_Tab_ExecTime $exectime,
                                Cron_Job $job){
        $this->setExecTime($exectime);
        $this->setCronJob($job);
    }

    public function setExecTime(Cron_Tab_ExecTime $exectime){
        $this->exectime = $exectime;
        return $this;
    }
    public function getExecTime(){
        return $this->exectime;
    }
    public function setCronJob(Cron_Job $job){
        $this->job = $job;
        return $this;
    }
    public function getCronJob(){
        return $this->job;
    }

    public function shallRun(Zend_Date $date=null){
        if(is_null($date)){
            $date = Zend_Date::now();
        }
        return $this->exectime->doesMatch($date);
    }

}

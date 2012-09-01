<?php

require_once('Cron/Tab/Entry.php');

class Cron_Tab implements IteratorAggregate{
    protected $entries = array();

    public function delEntry(Cron_Tab_Entry $entry){
        $hash = spl_object_hash($entry);
        unset($this->entries[$hash]);
    }
    public function addEntry(Cron_Tab_Entry $entry){
        $hash = spl_object_hash($entry);
        $this->entries[$hash] = $entry;
    }

    public function getIterator() {
        return new ArrayIterator($this->entries);
    }
}
